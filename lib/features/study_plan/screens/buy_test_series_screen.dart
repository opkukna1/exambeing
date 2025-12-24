import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class BuyTestSeriesScreen extends StatefulWidget {
  const BuyTestSeriesScreen({super.key});

  @override
  // Mixin for Lifecycle Observation
  State<BuyTestSeriesScreen> createState() => _BuyTestSeriesScreenState();
}

class _BuyTestSeriesScreenState extends State<BuyTestSeriesScreen> with WidgetsBindingObserver {
  
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  bool _isAvailable = false;
  bool _purchasePending = false;
  
  // 🔥 DEBUG LOG VARIABLE
  String _debugLog = "System Ready. Waiting for action...";

  // 📝 LOGGING FUNCTION (Screen par dikhane ke liye)
  void _log(String message) {
    debugPrint(message); // Console mein bhi
    if (mounted) {
      setState(() {
        _debugLog = "$message\n$_debugLog"; // Screen par bhi (Top pe naya msg)
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // 1. Observer Add karo (App Background/Resume detect karne ke liye)
    WidgetsBinding.instance.addObserver(this);

    // 2. Stream Setup
    final Stream<List<PurchaseDetails>> purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      _log("🔴 Stream System Error: $error");
    });
    
    _initStore();

    // 3. Auto-Check on Startup
    Future.delayed(const Duration(seconds: 1), () {
        _log("♻️ Checking for stuck/past payments...");
        _inAppPurchase.restorePurchases();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription.cancel();
    super.dispose();
  }

  // 🔥 4. APP RESUME DETECTOR
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _log("--------------------------------");
      _log("📲 App Resumed (User wapas aaya)");
      _log("🔄 Re-checking Google for status...");
      _inAppPurchase.restorePurchases();
    }
  }

  Future<void> _initStore() async {
    try {
      _isAvailable = await _inAppPurchase.isAvailable();
      _log(_isAvailable ? "✅ Store Connected" : "❌ Store NOT Available");
    } catch (e) {
      _log("❌ Init Error: $e");
    }
    setState(() {});
  }

  // --- 5. PAYMENT LISTENER ( The 'Ear' of the App) ---
  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    if (purchaseDetailsList.isEmpty) return;

    for (var purchaseDetails in purchaseDetailsList) {
      _log("📩 Event: ${purchaseDetails.productID} | Status: ${purchaseDetails.status}");

      if (purchaseDetails.status == PurchaseStatus.pending) {
        _log("⏳ Payment Processing... (Don't close app)");
        setState(() { _purchasePending = true; });
      } 
      else if (purchaseDetails.status == PurchaseStatus.error) {
        String err = purchaseDetails.error?.message ?? "Unknown";
        String errCode = purchaseDetails.error?.code ?? "No Code";
        _log("❌ FAILED: $err (Code: $errCode)");
        setState(() { _purchasePending = false; });

        // Auto-Fix for 'Already Owned'
        if (err.contains("Already Owned") || err.contains("itemAlreadyOwned")) {
           _log("♻️ Item is already owned. Attempting Unlock...");
           await _unlockContentLogic(purchaseDetails.productID);
        }
      } 
      else if (purchaseDetails.status == PurchaseStatus.purchased || purchaseDetails.status == PurchaseStatus.restored) {
        _log("✅ PAYMENT VERIFIED! Starting Database Write...");
        await _unlockContentLogic(purchaseDetails.productID);
      }

      if (purchaseDetails.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchaseDetails);
        _log("🏁 Transaction marked complete.");
      }
    }
  }

  // --- 6. UNLOCK LOGIC (Deep Debugging Version) ---
  Future<void> _unlockContentLogic(String googleProductId) async {
    final user = FirebaseAuth.instance.currentUser;
    
    // CHECK 1: User Login
    if (user == null) {
       _log("❌ CRITICAL ERROR: User is not logged in!");
       _log("👉 Fix: Login again.");
       return;
    }
    _log("👤 User verified: ${user.email}");

    try {
      // CHECK 2: Product ID Match
      _log("🔍 Step 1: Searching Firestore for ID: '$googleProductId'");
      var query = await FirebaseFirestore.instance
          .collection('premium_test_series')
          .where('productId', isEqualTo: googleProductId)
          .get();

      if (query.docs.isEmpty) {
        _log("❌ FATAL ERROR: Product ID '$googleProductId' NOT FOUND in DB.");
        _log("👉 Fix: Check spelling in Admin Panel vs Google Console.");
        return;
      }

      // CHECK 3: Schedule ID Link
      var premiumDoc = query.docs.first;
      String linkedScheduleId = premiumDoc['linkedScheduleId'] ?? "";
      
      if (linkedScheduleId.isEmpty) {
         _log("❌ DATA ERROR: linkedScheduleId is empty in Firestore!");
         _log("👉 Fix: Edit product in Admin & add Schedule ID.");
         return;
      }
      _log("📂 Step 2: Found Doc. Linked Schedule: $linkedScheduleId");

      // CHECK 4: Writing to Database (Permission/Network)
      _log("✍️ Step 3: Writing to 'allowed_users'...");
      
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
            'method': 'GooglePlay_Verified',
            'transaction_id': googleProductId // Just for record
          });

      _log("✅ WRITE SUCCESS! Unlock Complete.");
      
      // UI Update
      if(mounted) {
        setState(() { _purchasePending = false; });
        _showSuccessDialog();
      }

    } on FirebaseException catch (e) {
      // CHECK 5: Firestore Specific Errors
      _log("❌ FIRESTORE ERROR: [${e.code}] - ${e.message}");
      if (e.code == 'permission-denied') {
        _log("⚠️ HINT: Check Firestore Security Rules!");
      } else if (e.code == 'unavailable') {
        _log("⚠️ HINT: Internet issue or Offline mode.");
      }
    } catch (e) {
      _log("❌ UNKNOWN EXCEPTION: $e");
    }
  }

  void _showSuccessDialog() {
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text("🎉 Unlocked!"),
      content: const Text("Purchase successful. Your course is unlocked."),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("OK"))],
    ));
  }
  
  void _buyProduct(String productId) async {
    _log("--------------------------------");
    _log("🛒 BUY BUTTON PRESSED for: $productId");
    
    if (!_isAvailable) {
       _log("❌ Store is not available.");
       return;
    }
    
    Set<String> _kIds = {productId};
    final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(_kIds);
    if (response.notFoundIDs.isNotEmpty) {
        _log("❌ GOOGLE ERROR: Product ID '$productId' not found in Play Store.");
        return;
    }
    _log("✅ Product Found. Launching Pay Sheet...");
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: response.productDetails.first);
    _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text("Premium Store"), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
      body: Column(
        children: [
          // PRODUCT LIST
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('premium_test_series').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                    String productId = data['productId'] ?? '';
                    bool isOwned = (data['allowedEmails'] as List? ?? []).contains(user?.email);

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 20),
                      child: Padding(
                        padding: const EdgeInsets.all(15),
                        child: Column(
                          children: [
                            Text(data['title'] ?? 'Title', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 5),
                            Text(data['description'] ?? 'Desc', style: const TextStyle(color: Colors.grey)),
                            const SizedBox(height: 15),
                            
                            SizedBox(
                              width: double.infinity,
                              height: 45,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: isOwned ? Colors.green : Colors.black),
                                onPressed: isOwned ? null : () => _buyProduct(productId),
                                child: Text(isOwned ? "UNLOCKED" : "BUY FOR ${data['price']}", style: const TextStyle(color: Colors.white)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          
          // 🔥🔥 ADVANCED BLACK DEBUG CONSOLE 🔥🔥
          Container(
            height: 180, // Thoda bada console taaki sab dikhe
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            color: Colors.black,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("🖥️ SYSTEM LOGS (Live):", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                const Divider(color: Colors.grey, height: 10),
                Expanded(
                  child: SingleChildScrollView(
                    reverse: true, // Auto-scroll to bottom
                    child: Text(
                      _debugLog,
                      style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontFamily: 'Courier', height: 1.4),
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
