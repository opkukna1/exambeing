import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async'; // Auto-sync ke liye

class ManageModeratorScreen extends StatefulWidget {
  const ManageModeratorScreen({super.key});

  @override
  State<ManageModeratorScreen> createState() => _ManageModeratorScreenState();
}

class _ManageModeratorScreenState extends State<ManageModeratorScreen> {
  // 🔥 ADMIN EMAIL (Sirf yahi email access kar sakta hai)
  final String _adminEmail = "opsiddh42@gmail.com";

  // --- 1. ADMIN PANEL UI ---
  @override
  Widget build(BuildContext context) {
    // 🔒 SECURITY CHECK START
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email?.trim().toLowerCase() != _adminEmail) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.gpp_bad_rounded, size: 80, color: Colors.red.shade300),
              const SizedBox(height: 20),
              const Text(
                "🚫 ACCESS DENIED",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
              ),
              const SizedBox(height: 5),
              const Text("You are not authorized to view this panel."),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context), 
                child: const Text("Go Back")
              )
            ],
          ),
        ),
      );
    }
    // 🔒 SECURITY CHECK END

    return Scaffold(
      backgroundColor: Colors.grey[100], 
      appBar: AppBar(
        title: const Text("Manage Moderators 📡", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddModeratorDialog,
        backgroundColor: Colors.deepPurple,
        icon: const Icon(Icons.person_add),
        label: const Text("Assign New"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('moderator_assignments')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.supervised_user_circle_outlined, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 10),
                  const Text("No moderators assigned yet.", style: TextStyle(color: Colors.grey)),
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
              
              // 🔥 Admin Card (Only for opsiddh42@gmail.com)
              return _AdminFeederCard(
                docId: doc.id,
                data: data,
                onEdit: () => _showEditModeratorDialog(doc.id, data),
                onPay: (int balance, String name) => _showAddWithdrawalDialog(doc.id, name, balance),
                onDelete: () => _deleteModerator(doc.id),
              );
            },
          );
        },
      ),
    );
  }

  // --- 🗑️ DELETE MODERATOR ---
  void _deleteModerator(String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Moderator?"),
        content: const Text("This will remove their access and history. Are you sure?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('moderator_assignments').doc(docId).delete();
              if (mounted) Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  // --- ✏️ EDIT DIALOG ---
  void _showEditModeratorDialog(String docId, Map<String, dynamic> data) {
    final sIdC = TextEditingController(text: data['scheduleId']);
    final titleC = TextEditingController(text: data['scheduleTitle']);
    final commC = TextEditingController(text: (data['commissionPrice'] ?? 0).toString());
    final nameC = TextEditingController(text: data['moderatorName']);

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Edit Details ✏️"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _tf(nameC, "Moderator Name"),
              _tf(sIdC, "Schedule ID"),
              _tf(titleC, "Exam Name"),
              _tf(commC, "Commission Rate (₹)", isNum: true),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('moderator_assignments').doc(docId).update({
                'moderatorName': nameC.text.trim(),
                'scheduleId': sIdC.text.trim(),
                'scheduleTitle': titleC.text.trim(),
                'commissionPrice': int.tryParse(commC.text.trim()) ?? 0
              });
              if(mounted) Navigator.pop(c);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
            child: const Text("Update"),
          )
        ],
      ),
    );
  }

  // --- 💰 PAY DIALOG ---
  void _showAddWithdrawalDialog(String docId, String name, int balance) {
    final amtC = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text("Pay $name 💸"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Pending Balance: ", style: TextStyle(color: Colors.green)),
                  Text("₹$balance", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                ],
              ),
            ),
            const SizedBox(height: 15),
            _tf(amtC, "Enter Amount", isNum: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              int amt = int.tryParse(amtC.text.trim()) ?? 0;
              if (amt > 0) {
                await FirebaseFirestore.instance.collection('moderator_assignments').doc(docId).update({
                  'totalWithdrawn': FieldValue.increment(amt),
                  'withdrawalHistory': FieldValue.arrayUnion([
                    {'amount': amt, 'date': DateTime.now().toIso8601String()}
                  ])
                });
                if(mounted) Navigator.pop(c);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text("Pay Now"),
          )
        ],
      ),
    );
  }

  // --- ➕ ASSIGN DIALOG ---
  void _showAddModeratorDialog() {
    final emailC = TextEditingController(); final nameC = TextEditingController(); final scheduleIdC = TextEditingController(); final scheduleTitleC = TextEditingController(); final commissionC = TextEditingController();
    showDialog(context: context, builder: (c) => AlertDialog(title: const Text("Assign New Moderator"), content: SingleChildScrollView(child: Column(children: [_tf(emailC, "Email (Small Letters)"), _tf(nameC, "Name"), _tf(scheduleIdC, "Schedule ID (Exact)"), _tf(scheduleTitleC, "Exam Name"), _tf(commissionC, "Commission Rate", isNum: true)])), actions: [TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("Cancel")), ElevatedButton(onPressed: () async {
      if(emailC.text.isNotEmpty && scheduleIdC.text.isNotEmpty) {
        await FirebaseFirestore.instance.collection('moderator_assignments').add({
          'moderatorEmail': emailC.text.trim().toLowerCase(), 'moderatorName': nameC.text.trim(), 'scheduleId': scheduleIdC.text.trim(), 'scheduleTitle': scheduleTitleC.text.trim(), 'commissionPrice': int.tryParse(commissionC.text.trim())??0, 
          'totalWithdrawn': 0, 'withdrawalHistory': [], 
          'studentCount': 0, 'totalEarnings': 0, 
          'createdAt': FieldValue.serverTimestamp() 
        }); Navigator.pop(c);
      }
    }, style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white), child: const Text("Assign"))]));
  }

  Widget _tf(TextEditingController c, String l, {bool isNum = false}) => Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: c, keyboardType: isNum ? TextInputType.number : TextInputType.text, decoration: InputDecoration(labelText: l, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14))));
}

// --- 📡 FEEDER CARD LOGIC ---
class _AdminFeederCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final Function(int, String) onPay;
  final VoidCallback onDelete;

  const _AdminFeederCard({required this.docId, required this.data, required this.onEdit, required this.onPay, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    String scheduleId = (data['scheduleId'] ?? '').toString().trim();
    Timestamp joinedAt = data['createdAt'] ?? Timestamp.now();
    int commission = data['commissionPrice'] ?? 0;
    int totalWithdrawn = data['totalWithdrawn'] ?? 0;
    
    // DB values
    int dbStudentCount = data['studentCount'] ?? 0;
    int dbEarnings = data['totalEarnings'] ?? 0;

    return StreamBuilder<QuerySnapshot>(
      // 1. Calculate REAL Count
      stream: FirebaseFirestore.instance
          .collection('study_schedules')
          .doc(scheduleId)
          .collection('allowed_users')
          .where('grantedAt', isGreaterThanOrEqualTo: joinedAt) // Time Filter
          .snapshots(),
      builder: (context, studentSnap) {
        
        int liveCount = 0;
        if (studentSnap.hasData) liveCount = studentSnap.data!.docs.length;
        
        int liveEarnings = liveCount * commission;
        int liveBalance = liveEarnings - totalWithdrawn;

        // 2. 🔥 SYNC LOGIC
        if (liveCount != dbStudentCount || liveEarnings != dbEarnings) {
          Future.microtask(() {
            FirebaseFirestore.instance.collection('moderator_assignments').doc(docId).update({
              'studentCount': liveCount,
              'totalEarnings': liveEarnings,
              'lastSynced': FieldValue.serverTimestamp(),
            });
          });
        }

        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data['moderatorName'] ?? 'Name', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(height: 4),
                          Text("${data['scheduleTitle']}", style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold, fontSize: 13)),
                          Text("ID: $scheduleId", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(onPressed: onEdit, icon: const Icon(Icons.edit, color: Colors.blue), tooltip: "Edit"),
                        IconButton(onPressed: onDelete, icon: const Icon(Icons.delete, color: Colors.redAccent), tooltip: "Delete"),
                      ],
                    )
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statItem("Students", "$liveCount"),
                    _statItem("Earnings", "₹$liveEarnings", color: Colors.blue),
                    _statItem("Paid", "₹$totalWithdrawn", color: Colors.orange),
                  ],
                ),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.withOpacity(0.3))
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Pending Pay", style: TextStyle(color: Colors.green, fontSize: 11)),
                          Text("₹$liveBalance", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 18)),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () => onPay(liveBalance, data['moderatorName'] ?? 'Moderator'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
                        ),
                        icon: const Icon(Icons.attach_money, size: 18),
                        label: const Text("PAY NOW"),
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statItem(String label, String value, {Color color = Colors.black}) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
