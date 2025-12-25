import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async'; // Auto-sync ke liye

class ManageModeratorScreen extends StatefulWidget {
  const ManageModeratorScreen({super.key});

  @override
  State<ManageModeratorScreen> createState() => _ManageModeratorScreenState();
}

class _ManageModeratorScreenState extends State<ManageModeratorScreen> {
  // --- 1. ADMIN PANEL UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Moderators (Admin) 📡"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddModeratorDialog,
        backgroundColor: Colors.deepPurple,
        icon: const Icon(Icons.add),
        label: const Text("Assign New"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('moderator_assignments')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No moderators assigned yet."));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;
              
              // 🔥 Admin Card jo Data Feed karega
              return _AdminFeederCard(
                docId: doc.id,
                data: data,
                onEdit: _showEditModeratorDialog,
                onPay: _showAddWithdrawalDialog,
              );
            },
          );
        },
      ),
    );
  }

  // --- DIALOGS (Add, Edit, Pay) ---
  void _showAddModeratorDialog() {
    final emailC = TextEditingController(); final nameC = TextEditingController(); final scheduleIdC = TextEditingController(); final scheduleTitleC = TextEditingController(); final commissionC = TextEditingController();
    showDialog(context: context, builder: (c) => AlertDialog(title: const Text("Assign New"), content: SingleChildScrollView(child: Column(children: [_tf(emailC, "Email (Small Letters)"), _tf(nameC, "Name"), _tf(scheduleIdC, "Schedule ID (Exact)"), _tf(scheduleTitleC, "Exam Name"), _tf(commissionC, "Commission Rate", isNum: true)])), actions: [TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("Cancel")), ElevatedButton(onPressed: () async {
      if(emailC.text.isNotEmpty && scheduleIdC.text.isNotEmpty) {
        await FirebaseFirestore.instance.collection('moderator_assignments').add({
          'moderatorEmail': emailC.text.trim().toLowerCase(), 'moderatorName': nameC.text.trim(), 'scheduleId': scheduleIdC.text.trim(), 'scheduleTitle': scheduleTitleC.text.trim(), 'commissionPrice': int.tryParse(commissionC.text.trim())??0, 
          'totalWithdrawn': 0, 'withdrawalHistory': [], 
          'studentCount': 0, 'totalEarnings': 0, // Initial 0
          'createdAt': FieldValue.serverTimestamp() // Is time ke baad wale count honge
        }); Navigator.pop(c);
      }
    }, child: const Text("Assign"))]));
  }
  // (Edit aur Pay dialogs same rahenge, space bachane ke liye short kar raha hu, aap purana use kar sakte hain)
  void _showEditModeratorDialog(String docId, String sId, String title, int comm) { /* Same as before */ }
  void _showAddWithdrawalDialog(String docId, String name, int withdrawn, int balance) { /* Same as before */ }
  Widget _tf(TextEditingController c, String l, {bool isNum = false}) => Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: c, keyboardType: isNum ? TextInputType.number : TextInputType.text, decoration: InputDecoration(labelText: l, border: const OutlineInputBorder())));
}

// --- FEEDER CARD LOGIC ---
class _AdminFeederCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final Function onEdit;
  final Function onPay;

  const _AdminFeederCard({required this.docId, required this.data, required this.onEdit, required this.onPay});

  @override
  Widget build(BuildContext context) {
    String scheduleId = (data['scheduleId'] ?? '').toString().trim();
    Timestamp joinedAt = data['createdAt'] ?? Timestamp.now();
    int commission = data['commissionPrice'] ?? 0;
    int totalWithdrawn = data['totalWithdrawn'] ?? 0;
    
    // DB mein abhi kya value hai?
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

        // 2. 🔥 SYNC LOGIC: Agar Farq hai, to DB Update karo
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
          margin: const EdgeInsets.only(bottom: 15),
          child: ListTile(
            title: Text(data['moderatorName'] ?? 'Name', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("${data['scheduleTitle']} (ID: $scheduleId)"),
              Text("Sync Status: ${liveCount} Students, ₹$liveEarnings Earnings", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
            ]),
            trailing: IconButton(icon: const Icon(Icons.edit), onPressed: () => onEdit(docId, scheduleId, data['scheduleTitle'], commission)),
          ),
        );
      },
    );
  }
}
