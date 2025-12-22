import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class BuyTestSeriesScreen extends StatefulWidget {
  const BuyTestSeriesScreen({super.key});

  @override
  State<BuyTestSeriesScreen> createState() => _BuyTestSeriesScreenState();
}

class _BuyTestSeriesScreenState extends State<BuyTestSeriesScreen> {
  // 🔥 ADMIN EMAIL - Sirf isko add/delete button dikhega
  final String adminEmail = "opsiddh42@gmail.com";

  // --- 1. ADMIN LOGIC: ADD NEW SERIES ---
  void _showAddSeriesDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final priceController = TextEditingController();
    final phoneController = TextEditingController(); // Specific WhatsApp for this series
    final totalTestsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Admin: Add Test Series 🛠️"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(titleController, "Exam Name (e.g. NEET 2025)"),
              const SizedBox(height: 10),
              _buildTextField(descController, "Description/Features", maxLines: 2),
              const SizedBox(height: 10),
              _buildTextField(priceController, "Price (e.g. ₹499)"),
              const SizedBox(height: 10),
              _buildTextField(totalTestsController, "Total Tests (e.g. 50 Tests)"),
              const SizedBox(height: 10),
              _buildTextField(phoneController, "WhatsApp Number (e.g. 919876543210)", isPhone: true),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            onPressed: () async {
              if (titleController.text.isNotEmpty && phoneController.text.isNotEmpty) {
                // Save to Firestore
                await FirebaseFirestore.instance.collection('premium_test_series').add({
                  'title': titleController.text.trim(),
                  'description': descController.text.trim(),
                  'price': priceController.text.trim(),
                  'totalTests': totalTestsController.text.trim(),
                  'teacherWhatsapp': phoneController.text.trim(), // Specific number
                  'createdAt': FieldValue.serverTimestamp(),
                  'allowedEmails': [], // Empty list initially
                });
                if (mounted) Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Series Added!")));
              }
            },
            child: const Text("Save Series", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  // Helper for TextField
  Widget _buildTextField(TextEditingController controller, String hint, {bool isPhone = false, int maxLines = 1}) {
    return TextField(
      controller: controller,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  // --- 2. ADMIN LOGIC: DELETE SERIES ---
  void _deleteSeries(String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Series?"),
        content: const Text("This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('premium_test_series').doc(docId).delete();
              Navigator.pop(ctx);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          )
        ],
      ),
    );
  }

  // --- 3. WHATSAPP LOGIC (DYNAMIC) ---
  void _openWhatsApp(String phone, String seriesName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please Login first.")));
      return;
    }

    String email = user.email ?? "No Email";
    
    // Formatting Phone
    String finalPhone = phone.replaceAll(RegExp(r'\D'), ''); 
    if (!finalPhone.startsWith('91') && finalPhone.length == 10) {
      finalPhone = '91$finalPhone'; 
    }

    // ✨ REQUIRED MESSAGE FORMAT
    String message = "Sir I want to buy test series *$seriesName* and my email id is $email";
    
    final Uri url = Uri.parse("https://wa.me/$finalPhone?text=${Uri.encodeComponent(message)}");

    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch WhatsApp';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not open WhatsApp.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final bool isAdmin = user != null && user.email == adminEmail;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Premium Store 💎"),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      // 🔥 ADMIN ONLY FAB
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: _showAddSeriesDialog,
              backgroundColor: Colors.deepPurple,
              icon: const Icon(Icons.add),
              label: const Text("Add Test Series"),
            )
          : null,
      
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('premium_test_series').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_bag_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 10),
                  const Text("No Premium Series Added Yet", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;

              // Extract Data
              String title = data['title'] ?? 'Unnamed Series';
              String desc = data['description'] ?? 'No Description';
              String price = data['price'] ?? 'Paid';
              String totalTests = data['totalTests'] ?? 'N/A';
              String phone = data['teacherWhatsapp'] ?? ''; // Specific Number for this series
              
              // Check if already bought (Optional Logic for Badge)
              List allowedEmails = data['allowedEmails'] ?? [];
              bool isPurchased = allowedEmails.contains(user?.email);

              return Container(
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 8))],
                ),
                child: Column(
                  children: [
                    // --- 1. HEADER (Gold Gradient) ---
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFF2994A), Color(0xFFF2C94C)]),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)),
                            child: Text(isPurchased ? "UNLOCKED" : price, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                          // 🗑️ ADMIN DELETE BUTTON
                          if (isAdmin)
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.white),
                              onPressed: () => _deleteSeries(doc.id),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                        ],
                      ),
                    ),

                    // --- 2. BODY ---
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.checklist_rtl, color: Colors.deepPurple, size: 20),
                              const SizedBox(width: 8),
                              Text(totalTests, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(desc, style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.4)),
                          
                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 10),

                          // --- 3. BUY BUTTON ---
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isPurchased ? Colors.green : const Color(0xFF25D366), // WhatsApp Green
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              icon: Icon(isPurchased ? Icons.play_arrow : Icons.whatsapp, color: Colors.white),
                              label: Text(
                                isPurchased ? "OPEN TEST SERIES" : "BUY NOW (WhatsApp)",
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              onPressed: () {
                                if (isPurchased) {
                                  // Open Test Series (Self Study Page or Series Detail)
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Already Purchased! Go to Self Study.")));
                                } else {
                                  // 🔥 WHATSAPP TRIGGER
                                  if (phone.isNotEmpty) {
                                    _openWhatsApp(phone, title);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Teacher Contact Missing.")));
                                  }
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
