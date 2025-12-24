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

class _BuyTestSeriesScreenState extends State<BuyTestSeriesScreen> {
  final String adminEmail = "opsiddh42@gmail.com";
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  
  bool _isAvailable = false;
  bool _purchasePending = false;

  // 🔥 NEW: Debug Log Variable (Screen par dikhane ke liye)
  String _debugLog = "Status: Ready...";

  @override
  void initState() {
    super.initState();
    final Stream<List<PurchaseDetails>> purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      _log("Stream Error: $error"); // 👈 Log to screen
      setState(() { _purchasePending = false; });
    });
    _initStore();
  }

  // 🔥 NEW: Helper function to print logs on Screen
  void _log(String message) {
    debugPrint(message); // Console mein bhi dikhega
    setState(() {
      _debugLog = "$message\n$_debugLog"; // Screen par naya message upar aayega
    });
  }

  Future<void> _initStore() async {
    _isAvailable = await _inAppPurchase.isAvailable();
    _log("Store Available: $_isAvailable"); // 👈 Log
    setState(() {});
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        _log("Status: Payment Pending...");
        setState(() { _purchasePending = true; });
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          String errorMessage = purchaseDetails.error?.message ?? "Unknown Error";
          _log("❌ Error: $errorMessage");

          if (errorMessage.contains("itemAlreadyOwned") || errorMessage.contains("Already Owned")) {
             _log("⚠️ Item Already Owned. Trying Force Unlock...");
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text("Restoring Purchase..."), backgroundColor: Colors.green)
             );
             await _unlockContentLogic(purchaseDetails.productID);
          }
        } 
        else if (purchaseDetails.status == PurchaseStatus.purchased || purchaseDetails.status == PurchaseStatus.restored) {
          _log("✅ Payment Success/Restored. Unlocking...");
          await _unlockContentLogic(purchaseDetails.productID);
        }

        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
          _log("ℹ️ Purchase Completed/Acknowledged.");
        }
        setState(() { _purchasePending = false; });
      }
    }
  }

  Future<void> _unlockContentLogic(String googleProductId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      _log("❌ Error: User not logged in");
      return;
    }

    try {
      _log("🔍 Finding content for: $googleProductId");
      var query = await FirebaseFirestore.instance
          .collection('premium_test_series')
          .where('productId', isEqualTo: googleProductId)
          .get();

      if (query.docs.isNotEmpty) {
        var premiumDoc = query.docs.first;
        String linkedScheduleId = premiumDoc['linkedScheduleId'];
        
        _log("📂 Found Doc. Schedule ID: $linkedScheduleId");

        if (linkedScheduleId.isNotEmpty) {
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
                'method': 'GooglePlay/Restore'
              });

          await FirebaseFirestore.instance.collection('premium_test_series').doc(premiumDoc.id).update({
            'allowedEmails': FieldValue.arrayUnion([user.email])
          });

          _log("🎉 UNLOCK SUCCESSFUL!");
          if(mounted) _showSuccessDialog();
        } else {
           _log("❌ Error: Linked Schedule ID is empty!");
        }
      } else {
        _log("❌ Error: Product ID not found in Firestore!");
      }
    } catch (e) {
      _log("❌ Unlock Exception: $e");
    }
  }

  void _showSuccessDialog() {
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text("🎉 Unlocked!"),
      content: const Text("Purchase restored/verified successfully."),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("OK"))],
    ));
  }

  void _buyProduct(String productId) async {
    _log("🛒 Starting Buy Process for $productId");
    if (!_isAvailable) {
      _log("❌ Store Not Available");
      return;
    }
    
    Set<String> _kIds = {productId};
    final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(_kIds);
    if (response.notFoundIDs.isNotEmpty) {
      _log("❌ ID not found in Google Console: $productId");
      return;
    }
    _log("✅ Product Found. Launching Pay Sheet...");
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: response.productDetails.first);
    _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  // 🔥 NEW: MAGIC RESTORE BUTTON FUNCTION
  void _restorePurchases() {
    _log("♻️ 'Magic Fix' Triggered. Restoring...");
    _inAppPurchase.restorePurchases();
  }

  void _showAddSeriesDialog() {
     // (Same as before, removed to save space in this view)
     // ... Use your previous Admin Dialog code here ...
     // Just checking Firestore logic
  }

  void _deleteSeries(String docId) {
    FirebaseFirestore.instance.collection('premium_test_series').doc(docId).delete();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final bool isAdmin = user?.email?.toLowerCase().startsWith("opsiddh42") ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text("Premium Store 💎"), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
      // floatingActionButton: isAdmin ? FloatingActionButton(...) : null, // Restore your admin FAB
      
      body: Column(
        children: [
          // 1. PRODUCT LIST
          Expanded(
            child: Stack(
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('premium_test_series').orderBy('createdAt', descending: true).snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No Products"));

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        var doc = snapshot.data!.docs[index];
                        var data = doc.data() as Map<String, dynamic>;
                        String productId = data['productId'] ?? '';
                        bool isOwned = (data['allowedEmails'] as List? ?? []).contains(user?.email);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.15), blurRadius: 10)]),
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
                                  children: [
                                    Text(data['description'] ?? '', style: TextStyle(color: Colors.grey[600])),
                                    const SizedBox(height: 15),
                                    
                                    // ---- BUY BUTTON ----
                                    SizedBox(
                                      width: double.infinity,
                                      height: 45,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(backgroundColor: isOwned ? Colors.green : Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                        icon: Icon(isOwned ? Icons.check : Icons.shopping_cart, color: Colors.white),
                                        label: Text(isOwned ? "UNLOCKED" : "BUY FOR ${data['price']}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        onPressed: isOwned ? null : () => _buyProduct(productId),
                                      ),
                                    ),
                                    
                                    // 🔥🔥 NEW: MAGIC BUTTON (Near Buy) 🔥🔥
                                    if (!isOwned)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: TextButton.icon(
                                          onPressed: _restorePurchases, 
                                          icon: const Icon(Icons.refresh, size: 16, color: Colors.grey),
                                          label: const Text("Already paid? Fix/Restore Purchase", style: TextStyle(color: Colors.grey, fontSize: 12)),
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
          ),

          // 2. 🔥🔥 ON-SCREEN DEBUG CONSOLE 🔥🔥
          Container(
            height: 120, // Height of debug window
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            color: Colors.black,
            child: SingleChildScrollView(
              reverse: true, // Always show bottom logs
              child: Text(
                "DEBUG LOGS:\n$_debugLog",
                style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontFamily: 'Courier'),
              ),
            ),
          )
        ],
      ),
    );
  }
}
