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
  // 🔥 Debug Log Variable
  String _debugLog = "Status: Ready for DB Test...";
  bool _isLoading = false;

  // Logging Function
  void _log(String message) {
    debugPrint(message);
    setState(() {
      _debugLog = "$message\n$_debugLog";
    });
  }

  // --- 🔥 1. THE NEW "MAGIC DATABASE TESTER" FUNCTION ---
  Future<void> _testDirectDatabaseWrite(String googleProductId) async {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      _log("❌ Error: You are not logged in!");
      return;
    }

    setState(() { _isLoading = true; });
    _log("🚀 Starting DB Test for Product: $googleProductId");
    _log("👤 User: ${user.email}");

    try {
      // Step A: Find the Schedule ID attached to this product
      _log("1️⃣ Searching 'premium_test_series' for linked ID...");
      
      var query = await FirebaseFirestore.instance
          .collection('premium_test_series')
          .where('productId', isEqualTo: googleProductId)
          .get();

      if (query.docs.isEmpty) {
        _log("❌ Error: Product ID '$googleProductId' not found in premium_test_series collection.");
        setState(() { _isLoading = false; });
        return;
      }

      var premiumDoc = query.docs.first;
      String linkedScheduleId = premiumDoc['linkedScheduleId']; // 👈 ID fetch kar rahe hain
      
      _log("✅ Found Document. Linked Schedule ID: '$linkedScheduleId'");

      if (linkedScheduleId.isEmpty) {
        _log("❌ Error: 'linkedScheduleId' field is empty inside Firestore!");
        setState(() { _isLoading = false; });
        return;
      }

      // Step B: Write to the Study Schedule Subcollection
      _log("2️⃣ Attempting to write to: study_schedules/$linkedScheduleId/allowed_users/${user.email}");

      DateTime now = DateTime.now(); 
      DateTime expiry = now.add(const Duration(days: 365)); 

      await FirebaseFirestore.instance
          .collection('study_schedules')
          .doc(linkedScheduleId)
          .collection('allowed_users') // Subcollection
          .doc(user.email) // Doc ID is email
          .set({
            'email': user.email, 
            'grantedAt': Timestamp.fromDate(now), 
            'expiryDate': Timestamp.fromDate(expiry), 
            'access': true, 
            'method': 'Manual_DB_Test' // 👈 Tag taaki pata chale test tha
          });

      _log("✅ WRITE SUCCESS! Data saved in allowed_users.");

      // Step C: UI Update (Optional)
      _log("3️⃣ Updating 'premium_test_series' allowedEmails array...");
      await FirebaseFirestore.instance.collection('premium_test_series').doc(premiumDoc.id).update({
        'allowedEmails': FieldValue.arrayUnion([user.email])
      });

      _log("🎉 ALL OPERATIONS SUCCESSFUL! Check your Firestore now.");
      _showSuccessDialog();

    } catch (e) {
      _log("❌ CRITICAL ERROR: $e");
      if (e.toString().contains("permission-denied")) {
        _log("⚠️ HINT: Check Firestore Rules! User might not have 'write' permission.");
      }
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  void _showSuccessDialog() {
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text("✅ DB Write Success"),
      content: const Text("User successfully added to 'allowed_users'.\nGo check your Firestore Database now to verify fields."),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("OK"))],
    ));
  }

  // --- Dummy Payment Code (Ignored for this test) ---
  @override
  void initState() { super.initState(); }
  @override
  void dispose() { super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text("DB Tester Mode 🛠️"), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
      body: Column(
        children: [
          // LIST OF PRODUCTS
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
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
                    bool isOwned = (data['allowedEmails'] as List? ?? []).contains(user?.email);

                    return Card(
                      elevation: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Text(data['title'] ?? 'Test Series', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Text("ID: $productId", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 10),
                            
                            if (isOwned)
                              const Text("✅ ALREADY UNLOCKED (UI Check)", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                            else
                              Column(
                                children: [
                                  // 🛠️ THE MAGIC TEST BUTTON
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                                      icon: const Icon(Icons.build, color: Colors.white),
                                      label: const Text("🛠️ TEST DB WRITE (Bypass Pay)", style: TextStyle(color: Colors.white)),
                                      onPressed: _isLoading ? null : () => _testDirectDatabaseWrite(productId),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  const Text("This button writes directly to Firestore without payment.", style: TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // 🔥 DEBUG CONSOLE 🔥
          Container(
            height: 200, // Thoda bada kar diya taaki saare logs dikhein
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            color: Colors.black,
            child: SingleChildScrollView(
              reverse: true,
              child: Text(
                "DEBUG LOGS:\n$_debugLog",
                style: const TextStyle(color: Colors.greenAccent, fontSize: 13, fontFamily: 'Courier'),
              ),
            ),
          )
        ],
      ),
    );
  }
}
