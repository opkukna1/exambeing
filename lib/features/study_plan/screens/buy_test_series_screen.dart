import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class BuyTestSeriesScreen extends StatelessWidget {
  const BuyTestSeriesScreen({super.key});

  // 🔥 WhatsApp Open Logic
  void _openWhatsApp(BuildContext context, String examName, String teacherContact) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please Login first.")));
      return;
    }

    String email = user.email ?? "No Email";
    
    // Number Formatting (Remove spaces, ensure +91)
    String phone = teacherContact.replaceAll(RegExp(r'\D'), ''); 
    if (!phone.startsWith('91') && phone.length == 10) {
      phone = '91$phone'; 
    }

    // ✨ Ready-made Message
    String message = "Hello Sir, I want to purchase the Test Series: *$examName*.\n\nMy Email ID is: *$email*\n\nPlease provide payment details and allow access.";
    
    final Uri url = Uri.parse("https://wa.me/$phone?text=${Uri.encodeComponent(message)}");

    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch WhatsApp';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not open WhatsApp. Make sure it's installed.")));
    }
  }

  // 🛍️ POPUP DIALOG
  void _showBuyDialog(BuildContext context, Map<String, dynamic> data) {
    String examName = data['examName'] ?? 'Test Series';
    String price = data['price'] ?? 'Paid'; 
    String teacherContact = data['contactNumber'] ?? '8005576670'; // Default Number
    String description = data['description'] ?? 'Boost your preparation with this premium test series. Get access to weekly tests and analysis.';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            const Icon(Icons.lock_open_rounded, color: Colors.deepPurple, size: 40),
            const SizedBox(height: 10),
            Text("Unlock $examName", textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(description, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green)),
              child: Text("Price: $price", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
            icon: const Icon(Icons.whatsapp),
            label: const Text("BUY NOW"),
            onPressed: () {
              Navigator.pop(ctx); // Close Dialog
              _openWhatsApp(context, examName, teacherContact); // Open WhatsApp
            },
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Premium Test Series 💎"),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('study_schedules').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          var docs = snapshot.data!.docs;

          if (!snapshot.hasData || docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_bag_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 10),
                  const Text("No Test Series Available", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              String examName = data['examName'] ?? 'Unnamed Series';
              String totalTests = data['totalTests'] ?? 'Weekly'; 

              return GestureDetector(
                onTap: () => _showBuyDialog(context, data),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
                  ),
                  child: Column(
                    children: [
                      // Header Color Strip
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.deepPurple,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            // Icon Box
                            Container(
                              height: 60, width: 60,
                              decoration: BoxDecoration(
                                color: Colors.deepPurple.shade50,
                                borderRadius: BorderRadius.circular(15)
                              ),
                              child: const Icon(Icons.school, color: Colors.deepPurple, size: 30),
                            ),
                            const SizedBox(width: 15),
                            
                            // Text Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(examName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      const Icon(Icons.verified, size: 14, color: Colors.green),
                                      const SizedBox(width: 4),
                                      Text("Full Access • $totalTests", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                    ],
                                  )
                                ],
                              ),
                            ),
                            
                            // Buy Button Icon
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(20)),
                              child: const Text("BUY", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                            )
                          ],
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
    );
  }
}
