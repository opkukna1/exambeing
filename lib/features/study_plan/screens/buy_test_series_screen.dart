import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'series_detail_screen.dart'; // 👈 Import the new screen

class BuyTestSeriesScreen extends StatefulWidget {
  const BuyTestSeriesScreen({super.key});

  @override
  State<BuyTestSeriesScreen> createState() => _BuyTestSeriesScreenState();
}

class _BuyTestSeriesScreenState extends State<BuyTestSeriesScreen> with WidgetsBindingObserver {
  final String adminEmail = "opsiddh42@gmail.com";
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  bool _isAvailable = false;
  bool _purchasePending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final Stream<List<PurchaseDetails>> purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen(_listenToPurchaseUpdated, onDone: () => _subscription.cancel(), onError: (e) => setState(() => _purchasePending = false));
    _initStore();
    Future.delayed(const Duration(seconds: 1), () => _inAppPurchase.restorePurchases());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _inAppPurchase.restorePurchases();
  }

  Future<void> _initStore() async {
    _isAvailable = await _inAppPurchase.isAvailable();
    if(mounted) setState(() {});
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        setState(() { _purchasePending = true; });
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${purchaseDetails.error?.message}")));
        } else if (purchaseDetails.status == PurchaseStatus.purchased || purchaseDetails.status == PurchaseStatus.restored) {
           await _unlockContentLogic(purchaseDetails.productID);
        }
        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
        setState(() { _purchasePending = false; });
      }
    }
  }

  Future<void> _unlockContentLogic(String googleProductId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    var query = await FirebaseFirestore.instance.collection('premium_test_series').where('productId', isEqualTo: googleProductId).get();
    if (query.docs.isNotEmpty) {
      var premiumDoc = query.docs.first;
      String linkedScheduleId = premiumDoc['linkedScheduleId'];
      DateTime now = DateTime.now(); 
      DateTime expiry = now.add(const Duration(days: 365));

      await FirebaseFirestore.instance.collection('study_schedules').doc(linkedScheduleId).collection('allowed_users').doc(user.email).set({
        'email': user.email, 'grantedAt': Timestamp.fromDate(now), 'expiryDate': Timestamp.fromDate(expiry), 'access': true, 'method': 'GooglePlay'
      });
      await FirebaseFirestore.instance.collection('premium_test_series').doc(premiumDoc.id).update({'allowedEmails': FieldValue.arrayUnion([user.email])});
    }
  }

  void _buyProduct(String productId) async {
    if (!_isAvailable) return;
    Set<String> _kIds = {productId};
    final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(_kIds);
    if (response.notFoundIDs.isEmpty) {
      _inAppPurchase.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: response.productDetails.first));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Product ID not found in Console")));
    }
  }

  // --- ADMIN DIALOG ---
  void _showAddSeriesDialog() {
     final titleC = TextEditingController();
     final descC = TextEditingController();
     final priceC = TextEditingController();
     final productIdC = TextEditingController();
     final scheduleIdC = TextEditingController();

     showDialog(context: context, builder: (c) => AlertDialog(
       title: const Text("Add Product"),
       content: Column(mainAxisSize: MainAxisSize.min, children: [
         TextField(controller: titleC, decoration: const InputDecoration(labelText: "Title")),
         TextField(controller: descC, decoration: const InputDecoration(labelText: "Description")),
         TextField(controller: priceC, decoration: const InputDecoration(labelText: "Price (e.g. ₹99)")),
         TextField(controller: productIdC, decoration: const InputDecoration(labelText: "Google Product ID")),
         TextField(controller: scheduleIdC, decoration: const InputDecoration(labelText: "Linked Schedule ID")),
       ]),
       actions: [
         ElevatedButton(onPressed: () async {
           await FirebaseFirestore.instance.collection('premium_test_series').add({
             'title': titleC.text, 'description': descC.text, 'price': priceC.text, 
             'productId': productIdC.text, 'linkedScheduleId': scheduleIdC.text, 
             'createdAt': FieldValue.serverTimestamp(), 'allowedEmails': []
           });
           Navigator.pop(c);
         }, child: const Text("Save"))
       ],
     ));
  }

  void _deleteSeries(String docId) {
    FirebaseFirestore.instance.collection('premium_test_series').doc(docId).delete();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final bool isAdmin = user?.email == adminEmail;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(title: const Text("Premium Store 💎"), centerTitle: true, elevation: 0),
      floatingActionButton: isAdmin ? FloatingActionButton(onPressed: _showAddSeriesDialog, child: const Icon(Icons.add)) : null,
      
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('premium_test_series').orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var doc = snapshot.data!.docs[index];
                  var data = doc.data() as Map<String, dynamic>;
                  String productId = data['productId'] ?? '';
                  String scheduleId = data['linkedScheduleId'] ?? '';
                  bool isOwned = (data['allowedEmails'] as List? ?? []).contains(user?.email);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)]),
                    child: Column(
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: isOwned ? [Colors.green, Colors.green.shade700] : [Colors.deepPurple, Colors.deepPurple.shade700]),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20))
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text(data['title'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
                              if(isAdmin) IconButton(icon: const Icon(Icons.delete, color: Colors.white), onPressed: () => _deleteSeries(doc.id))
                            ],
                          ),
                        ),
                        
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data['description'] ?? '', style: TextStyle(color: Colors.grey[600])),
                              const SizedBox(height: 20),
                              
                              // 🔥🔥 MODIFIED BUTTONS ROW 🔥🔥
                              Row(
                                children: [
                                  // 1. FREE DEMO BUTTON (Small)
                                  if (!isOwned)
                                  Expanded(
                                    flex: 4,
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        side: const BorderSide(color: Colors.deepPurple),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                                      ),
                                      onPressed: () {
                                        // Go to Schedule Screen
                                        Navigator.push(context, MaterialPageRoute(builder: (_) => SeriesDetailScreen(
                                          scheduleDocId: scheduleId, 
                                          title: data['title'] ?? 'Schedule'
                                        )));
                                      },
                                      child: const Text("📄 Demo / Schedule", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                  
                                  if (!isOwned) const SizedBox(width: 10),

                                  // 2. BUY BUTTON (Big)
                                  Expanded(
                                    flex: 6, // Buy button thoda bada rahega
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isOwned ? Colors.green : Colors.black,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                                      ),
                                      onPressed: isOwned ? null : () => _buyProduct(productId),
                                      child: Text(
                                        isOwned ? "UNLOCKED" : "BUY ${data['price']}", 
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                                      ),
                                    ),
                                  ),
                                ],
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
