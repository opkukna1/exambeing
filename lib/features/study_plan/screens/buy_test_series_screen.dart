import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_purchase/in_app_purchase.dart'; // 📦 Payment Package

class BuyTestSeriesScreen extends StatefulWidget {
  const BuyTestSeriesScreen({super.key});

  @override
  State<BuyTestSeriesScreen> createState() => _BuyTestSeriesScreenState();
}

class _BuyTestSeriesScreenState extends State<BuyTestSeriesScreen> {
  // 🔥 ADMIN EMAIL
  final String adminEmail = "opsiddh42@gmail.com";

  // 💰 Payment Variables
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  bool _isAvailable = false;
  bool _purchasePending = false;

  @override
  void initState() {
    super.initState();
    final Stream<List<PurchaseDetails>> purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      setState(() { _purchasePending = false; });
    });
    _initStore();
  }

  Future<void> _initStore() async {
    _isAvailable = await _inAppPurchase.isAvailable();
    setState(() {});
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  // --- 1. LISTEN TO PAYMENT UPDATES ---
  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        setState(() { _purchasePending = true; });
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${purchaseDetails.error?.message}")));
        } else if (purchaseDetails.status == PurchaseStatus.purchased || purchaseDetails.status == PurchaseStatus.restored) {
          
          // 🎉 SUCCESS: Content Unlock Karo
          await _unlockContentLogic(purchaseDetails.productID);
        }

        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
        setState(() { _purchasePending = false; });
      }
    }
  }

  // --- 2. 🔥 MAIN UNLOCK LOGIC (LINKING SCHEDULE ID) ---
  Future<void> _unlockContentLogic(String googleProductId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    try {
      // Step A: Find the Premium Card using Google Product ID
      var query = await FirebaseFirestore.instance
          .collection('premium_test_series')
          .where('productId', isEqualTo: googleProductId)
          .get();

      if (query.docs.isNotEmpty) {
        var premiumDoc = query.docs.first;
        String linkedScheduleId = premiumDoc['linkedScheduleId']; // 👈 Yahan se Schedule ID milegi

        if (linkedScheduleId.isNotEmpty) {
          // Step B: Update the REAL Schedule in 'study_schedules'
          // User ki email ko 'allowed_users' subcollection mein daal rahe hain
          await FirebaseFirestore.instance
              .collection('study_schedules')
              .doc(linkedScheduleId)
              .collection('allowed_users') // Subcollection approach (Best for security)
              .doc(user.email) // Email ko hi Doc ID bana diya
              .set({
                'access': true,
                'purchasedAt': FieldValue.serverTimestamp(),
                'method': 'GooglePlay'
              });

          // Step C: Update Premium Card UI (Optional, just to show 'Owned' button)
          await FirebaseFirestore.instance.collection('premium_test_series').doc(premiumDoc.id).update({
            'allowedEmails': FieldValue.arrayUnion([user.email])
          });

          if(mounted) {
            _showSuccessDialog();
          }
        } else {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Admin hasn't linked a Schedule ID! Contact Support.")));
        }
      }
    } catch (e) {
      debugPrint("Unlock Error: $e");
    }
  }

  void _showSuccessDialog() {
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text("🎉 Purchase Successful!"),
      content: const Text("Your Test Series has been unlocked.\nGo to 'Self Study' section to start."),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("OK"))],
    ));
  }

  // --- 3. BUY TRIGGER ---
  void _buyProduct(String productId) async {
    if (!_isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Store Not Available")));
      return;
    }
    
    // Google Payment Popup
    Set<String> _kIds = {productId};
    final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(_kIds);
    if (response.notFoundIDs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Product ID not found in Console!")));
      return;
    }
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: response.productDetails.first);
    _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  // --- 4. ADMIN DIALOG (UPDATED FOR SCHEDULE ID) ---
  void _showAddSeriesDialog() {
    final titleC = TextEditingController();
    final descC = TextEditingController();
    final priceC = TextEditingController();
    final productIdC = TextEditingController(); // Google Play ID
    final scheduleIdC = TextEditingController(); // 🔥 REAL FIREBASE SCHEDULE ID
    final totalTestsC = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Admin: Add Product 🛒"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(titleC, "Display Name (e.g. NEET 2025)"),
              const SizedBox(height: 10),
              _buildTextField(descC, "Description"),
              const SizedBox(height: 10),
              _buildTextField(priceC, "Price Label (e.g. ₹499)"),
              const SizedBox(height: 10),
              _buildTextField(totalTestsC, "Total Tests info"),
              const SizedBox(height: 10),
              _buildTextField(productIdC, "Google Product ID (from Play Console)", isBold: true),
              const SizedBox(height: 10),
              // 👇 NEW FIELD FOR LINKING
              _buildTextField(scheduleIdC, "Linked Schedule ID (from Firestore)", isBold: true),
              const Text("Copy Doc ID from 'study_schedules' collection", style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            onPressed: () async {
              if (titleC.text.isNotEmpty && productIdC.text.isNotEmpty && scheduleIdC.text.isNotEmpty) {
                await FirebaseFirestore.instance.collection('premium_test_series').add({
                  'title': titleC.text.trim(),
                  'description': descC.text.trim(),
                  'price': priceC.text.trim(),
                  'totalTests': totalTestsC.text.trim(),
                  'productId': productIdC.text.trim(), // Google ID
                  'linkedScheduleId': scheduleIdC.text.trim(), // 🔥 Actual Content ID
                  'createdAt': FieldValue.serverTimestamp(),
                  'allowedEmails': [],
                });
                if (mounted) Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Linked Series Added!")));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⚠️ All IDs are required!")));
              }
            },
            child: const Text("Save", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {bool isBold = false}) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: hint, 
        labelStyle: isBold ? const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))
      ),
    );
  }

  void _deleteSeries(String docId) {
    FirebaseFirestore.instance.collection('premium_test_series').doc(docId).delete();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    // Admin Check
    final bool isAdmin = user?.email?.toLowerCase().startsWith("opsiddh42") ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text("Premium Store 💎"), backgroundColor: Colors.white, foregroundColor: Colors.black, centerTitle: true, elevation: 0),
      floatingActionButton: isAdmin ? FloatingActionButton.extended(onPressed: _showAddSeriesDialog, label: const Text("Add Product"), icon: const Icon(Icons.add), backgroundColor: Colors.deepPurple, foregroundColor: Colors.white) : null,
      
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('premium_test_series').orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No Products Available"));

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var doc = snapshot.data!.docs[index];
                  var data = doc.data() as Map<String, dynamic>;
                  String productId = data['productId'] ?? '';
                  // Check Ownership locally for UI update
                  bool isOwned = (data['allowedEmails'] as List? ?? []).contains(user?.email);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 5))]),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFF2994A), Color(0xFFF2C94C)]), borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text(data['title'] ?? 'Test Series', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                              if(isAdmin) IconButton(icon: const Icon(Icons.delete, color: Colors.white), onPressed: () => _deleteSeries(doc.id))
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(15),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data['description'] ?? '', style: TextStyle(color: Colors.grey[600])),
                              const SizedBox(height: 10),
                              if(isAdmin) Text("Linked Schedule ID: ${data['linkedScheduleId']}", style: const TextStyle(fontSize: 10, color: Colors.red)),
                              const SizedBox(height: 15),
                              SizedBox(
                                width: double.infinity,
                                height: 45,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: isOwned ? Colors.green : Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                  icon: Icon(isOwned ? Icons.check : Icons.shopping_cart, color: Colors.white),
                                  label: Text(isOwned ? "UNLOCKED" : "BUY FOR ${data['price']}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  onPressed: isOwned ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Already Owned! Go to Self Study."))) : () => _buyProduct(productId),
                                ),
                              )
                            ],
                          ),
                        )
                      ],
                    ),
                  );
                },
              );
            },
          ),
          if (_purchasePending) Container(color: Colors.black54, child: const Center(child: CircularProgressIndicator()))
        ],
      ),
    );
  }
}
