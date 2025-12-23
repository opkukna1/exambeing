import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 🔥 Auth Import Zaroori hai

class ManageModeratorScreen extends StatefulWidget {
  const ManageModeratorScreen({super.key});

  @override
  State<ManageModeratorScreen> createState() => _ManageModeratorScreenState();
}

class _ManageModeratorScreenState extends State<ManageModeratorScreen> {
  // 🔥 1. ADMIN CHECK (Hardcoded Security)
  final String adminEmail = "opsiddh42@gmail.com";

  bool get isAdmin {
    final user = FirebaseAuth.instance.currentUser;
    return user != null && user.email?.toLowerCase().trim() == adminEmail.toLowerCase().trim();
  }

  // --- 2. ADD NEW MODERATOR DIALOG ---
  void _showAddModeratorDialog() {
    final emailC = TextEditingController();
    final nameC = TextEditingController();
    final scheduleIdC = TextEditingController(); 
    final scheduleTitleC = TextEditingController(); 
    final commissionC = TextEditingController(); 

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Assign Moderator 🤝"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(emailC, "Moderator Email (Login Email)"),
              const SizedBox(height: 10),
              _buildTextField(nameC, "Moderator Name"),
              const SizedBox(height: 10),
              _buildTextField(scheduleIdC, "Linked Schedule ID (From Firestore)"),
              const SizedBox(height: 10),
              _buildTextField(scheduleTitleC, "Exam Name (e.g. NEET 2025)"),
              const SizedBox(height: 10),
              _buildTextField(commissionC, "Commission Per Student (₹)", isNumber: true),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            onPressed: () async {
              if (emailC.text.isNotEmpty && scheduleIdC.text.isNotEmpty && commissionC.text.isNotEmpty) {
                
                await FirebaseFirestore.instance.collection('moderator_assignments').add({
                  'moderatorEmail': emailC.text.trim().toLowerCase(),
                  'moderatorName': nameC.text.trim(),
                  'scheduleId': scheduleIdC.text.trim(),
                  'scheduleTitle': scheduleTitleC.text.trim(),
                  'commissionPrice': int.tryParse(commissionC.text.trim()) ?? 0,
                  'totalWithdrawn': 0, 
                  'withdrawalHistory': [], 
                  'createdAt': FieldValue.serverTimestamp(),
                });

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Moderator Assigned!")));
                }
              }
            },
            child: const Text("Assign", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  // --- 3. ADD WITHDRAWAL (PAYOUT) DIALOG ---
  void _showAddWithdrawalDialog(String docId, String name, int currentWithdrawn, int availableBalance) {
    final amountC = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Pay to $name 💸"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Available Balance: ₹$availableBalance", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 10),
            TextField(
              controller: amountC,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Enter Amount Paid", border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              int amount = int.tryParse(amountC.text.trim()) ?? 0;
              if (amount > 0) {
                await FirebaseFirestore.instance.collection('moderator_assignments').doc(docId).update({
                  'totalWithdrawn': FieldValue.increment(amount), 
                  'withdrawalHistory': FieldValue.arrayUnion([
                    {
                      'amount': amount,
                      'date': DateTime.now().toIso8601String(),
                    }
                  ])
                });
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text("Confirm Payment"),
          )
        ],
      ),
    );
  }

  void _showHistoryDialog(List<dynamic> history) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Payment History 📜"),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: history.isEmpty 
          ? const Center(child: Text("No payments made yet."))
          : ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, index) {
              var item = history[history.length - 1 - index]; 
              var date = DateTime.tryParse(item['date']) ?? DateTime.now();
              return ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: Text("₹${item['amount']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(DateFormat('dd MMM yyyy, hh:mm a').format(date)),
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
      ),
    );
  }

  Widget _buildTextField(TextEditingController c, String label, {bool isNumber = false}) {
    return TextField(
      controller: c,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 SECURITY CHECK: Agar Admin nahi hai to Access Denied
    if (!isAdmin) {
      return const Scaffold(
        body: Center(child: Text("Access Denied 🚫\nOnly Admin can view this.", textAlign: TextAlign.center)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Moderators 👥"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddModeratorDialog,
        backgroundColor: Colors.deepPurple,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Add Moderator", style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('moderator_assignments').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No moderators assigned yet."));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;

              String modName = data['moderatorName'] ?? 'Unknown';
              String scheduleId = data['scheduleId'] ?? '';
              int commission = data['commissionPrice'] ?? 0;
              int totalWithdrawn = data['totalWithdrawn'] ?? 0;
              List history = data['withdrawalHistory'] ?? [];

              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('study_schedules').doc(scheduleId).snapshots(),
                builder: (context, scheduleSnap) {
                  
                  int studentCount = 0;
                  if (scheduleSnap.hasData && scheduleSnap.data!.exists) {
                    var scheduleData = scheduleSnap.data!.data() as Map<String, dynamic>;
                    if (scheduleData.containsKey('purchasedUsers')) {
                      studentCount = (scheduleData['purchasedUsers'] as List).length;
                    }
                  }

                  int totalEarnings = studentCount * commission;
                  int availableBalance = totalEarnings - totalWithdrawn;

                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(modName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  Text(data['moderatorEmail'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text("Exam: ${data['scheduleTitle']}", style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.w600)),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  FirebaseFirestore.instance.collection('moderator_assignments').doc(doc.id).delete();
                                },
                              )
                            ],
                          ),
                          const Divider(height: 25),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text("Students", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                Text("$studentCount", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ]),
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text("Rate", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                Text("₹$commission", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ]),
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text("Total Earn", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                Text("₹$totalEarnings", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
                              ]),
                            ],
                          ),
                          const SizedBox(height: 15),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text("Paid", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                Text("₹$totalWithdrawn", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                              ]),
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text("Balance", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                Text("₹$availableBalance", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
                              ]),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.history), label: const Text("History"), onPressed: () => _showHistoryDialog(history))),
                              const SizedBox(width: 10),
                              Expanded(child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), icon: const Icon(Icons.attach_money), label: const Text("Pay Cash"), onPressed: () => _showAddWithdrawalDialog(doc.id, modName, totalWithdrawn, availableBalance))),
                            ],
                          )
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
