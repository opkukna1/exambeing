import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class BuyTestSeriesScreen extends StatefulWidget {
  const BuyTestSeriesScreen({super.key});

  @override
  State<BuyTestSeriesScreen> createState() => _BuyTestSeriesScreenState();
}

class _BuyTestSeriesScreenState extends State<BuyTestSeriesScreen> with WidgetsBindingObserver {
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
    WidgetsBinding.instance.addObserver(this);

    final Stream<List<PurchaseDetails>> purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      // Silent error handling in production
      setState(() { _purchasePending = false; });
    });
    
    _initStore();

    // Silent Restore on Start (To fix stuck payments without annoying user)
    Future.delayed(const Duration(seconds: 1), () {
        _inAppPurchase.restorePurchases();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription.cancel();
    super.dispose();
  }

  // ✅ APP RESUME LOGIC (Backbone of Success)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _inAppPurchase.restorePurchases();
    }
  }

  Future<void> _initStore() async {
    _isAvailable = await _inAppPurchase.isAvailable();
    if(mounted) setState(() {});
  }

  // --- 1. PAYMENT LISTENER ---
  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        setState(() { _purchasePending = true; });
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          String errorMessage = purchaseDetails.error?.message ?? "";
          
          // Auto-Fix for 'Already Owned'
          if (errorMessage.contains("Already Owned") || errorMessage.contains("itemAlreadyOwned")) {
             await _unlockContentLogic(purchaseDetails.productID, silent: true);
          } else {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Payment Failed: $errorMessage")));
          }
        } 
        else if (purchaseDetails.status == PurchaseStatus.purchased || purchaseDetails.status == PurchaseStatus.restored) {
          // Pass 'false' for silent if it's a fresh purchase, 'true' if restored
          bool isRestore = purchaseDetails.status == PurchaseStatus.restored;
          await _unlockContentLogic(purchaseDetails.productID, silent: isRestore);
        }

        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
        setState(() { _purchasePending = false; });
      }
    }
  }

  // --- 2. UNLOCK LOGIC (Smart Silent Mode) ---
  Future<void> _unlockContentLogic(String googleProductId, {bool silent = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      var query = await FirebaseFirestore.instance
          .collection('premium_test_series')
          .where('productId', isEqualTo: googleProductId)
          .get();

      if (query.docs.isNotEmpty) {
        var premiumDoc = query.docs.first;
        String linkedScheduleId = premiumDoc['linkedScheduleId'];

        if (linkedScheduleId.isNotEmpty) {
          
          // 🔥 CHECK: Agar user pehle se added hai, to dobara mat likho aur Dialog mat dikhao
          var userDoc = await FirebaseFirestore.instance
              .collection('study_schedules')
              .doc(linkedScheduleId)
              .collection('allowed_users')
              .doc(user.email)
              .get();

          if (userDoc.exists) {
            // Already unlocked. Do nothing.
            return; 
          }

          // Agar naya user hai, to hi Write karo
          DateTime now = DateTime.now(); 
          DateTime expiry = now.add(const Duration(days: 365));

          await FirebaseFirestore.instance
              .collection('study_schedules')
              .doc(linkedScheduleId)
              .collection('allowed_users')
              .doc(user.email)
              .set({
                'email': user.email, 
                'grantedAt': Timestamp.fromDate(now), 
                'expiryDate': Timestamp.fromDate(expiry), 
                'access': true, 
                'method': 'GooglePlay'
              });

          // UI Update
          await FirebaseFirestore.instance.collection('premium_test_series').doc(premiumDoc.id).update({
            'allowedEmails': FieldValue.arrayUnion([user.email])
          });

          // 🎉 Dialog tabhi dikhao jab Actually unlock hua ho
          if(mounted && !silent) {
            _showSuccessDialog();
          }
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  void _showSuccessDialog() {
    showDialog(context: context, builder: (c) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Column(
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 50),
          SizedBox(height: 10),
          Text("Purchase Successful!"),
        ],
      ),
      content: const Text("This Test Series has been unlocked.\nGo to 'Self Study' section to start."),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(c), 
          child: const Text("OK, Let's Start")
        )
      ],
    ));
  }

  void _buyProduct(String productId) async {
    if (!_isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Store Not Available")));
      return;
    }
    
    Set<String> _kIds = {productId};
    final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(_kIds);
    if (response.notFoundIDs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Product not found (Check Admin ID)")));
      return;
    }
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: response.productDetails.first);
    _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  // --- ADMIN FUNCTIONS ---
  void _showAddSeriesDialog() {
    final titleC = TextEditingController();
    final descC = TextEditingController();
    final priceC = TextEditingController();
    final productIdC = TextEditingController();
    final scheduleIdC = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add New Product"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleC, decoration: const InputDecoration(labelText: "Title (e.g. NEET 2025)")),
              TextField(controller: descC, decoration: const InputDecoration(labelText: "Description")),
              TextField(controller: priceC, decoration: const InputDecoration(labelText: "Price Label (e.g. ₹499)")),
              TextField(controller: productIdC, decoration: const InputDecoration(labelText: "Google Product ID (Exact)")),
              TextField(controller: scheduleIdC, decoration: const InputDecoration(labelText: "Linked Schedule Doc ID")),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (titleC.text.isNotEmpty && productIdC.text.isNotEmpty && scheduleIdC.text.isNotEmpty) {
                await FirebaseFirestore.instance.collection('premium_test_series').add({
                  'title': titleC.text.trim(),
                  'description': descC.text.trim(),
                  'price': priceC.text.trim(),
                  'productId': productIdC.text.trim(),
                  'linkedScheduleId': scheduleIdC.text.trim(),
                  'createdAt': FieldValue.serverTimestamp(),
                  'allowedEmails': [],
                });
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
  }

  void _deleteSeries(String docId) {
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text("Delete?"),
      content: const Text("This will remove the product card from the app."),
      actions: [
        TextButton(onPressed: ()=> Navigator.pop(c), child: const Text("Cancel")),
        TextButton(onPressed: () {
          FirebaseFirestore.instance.collection('premium_test_series').doc(docId).delete();
          Navigator.pop(c);
        }, child: const Text("Delete", style: TextStyle(color: Colors.red)))
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final bool isAdmin = user?.email == adminEmail;

    return Scaffold(
      backgroundColor: Colors.grey[100], // Light background
      appBar: AppBar(
        title: const Text("Premium Store 💎"), 
        backgroundColor: Colors.white, 
        foregroundColor: Colors.black, 
        elevation: 0,
        centerTitle: true,
      ),
      floatingActionButton: isAdmin ? FloatingActionButton.extended(
        onPressed: _showAddSeriesDialog, 
        label: const Text("Add Product"), 
        icon: const Icon(Icons.add), 
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ) : null,
      
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('premium_test_series').orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No Products Available", style: TextStyle(color: Colors.grey)));

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var doc = snapshot.data!.docs[index];
                  var data = doc.data() as Map<String, dynamic>;
                  String productId = data['productId'] ?? '';
                  bool isOwned = (data['allowedEmails'] as List? ?? []).contains(user?.email);

                  // --- MODERN UI CARD ---
                  return Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5))
                      ]
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Gradient
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isOwned 
                                ? [Colors.green.shade400, Colors.green.shade700] 
                                : [Colors.deepPurple.shade400, Colors.deepPurple.shade700],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight
                            ),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  data['title'] ?? 'Test Series', 
                                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)
                                ),
                              ),
                              if(isOwned) const Icon(Icons.verified, color: Colors.white),
                              if(isAdmin) IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.white70), 
                                onPressed: () => _deleteSeries(doc.id)
                              )
                            ],
                          ),
                        ),
                        
                        // Body
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data['description'] ?? 'Unlock full access to test series.', style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.5)),
                              const SizedBox(height: 20),
                              
                              if(isAdmin) Text("ID: $productId", style: const TextStyle(fontSize: 10, color: Colors.grey)),

                              // Buy Button
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isOwned ? Colors.white : Colors.black,
                                    foregroundColor: isOwned ? Colors.green : Colors.white,
                                    elevation: isOwned ? 0 : 5,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: isOwned ? const BorderSide(color: Colors.green) : BorderSide.none
                                    )
                                  ),
                                  onPressed: isOwned 
                                    ? null 
                                    : () => _buyProduct(productId),
                                  child: Text(
                                    isOwned ? "UNLOCKED & ACTIVE" : "BUY NOW • ${data['price']}", 
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isOwned ? Colors.green : Colors.white)
                                  ),
                                ),
                              ),
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
          
          // Loading Overlay
          if (_purchasePending) 
            Container(
              color: Colors.black54, 
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 20),
                    Text("Processing Secure Payment...", style: TextStyle(color: Colors.white))
                  ],
                )
              )
            )
        ],
      ),
    );
  }
}
