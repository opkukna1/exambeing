import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ManageModeratorScreen extends StatefulWidget {
  const ManageModeratorScreen({super.key});

  @override
  State<ManageModeratorScreen> createState() => _ManageModeratorScreenState();
}

class _ManageModeratorScreenState extends State<ManageModeratorScreen> {
  // 🔥 ADMIN CHECK
  final String adminEmail = "opsiddh42@gmail.com";

  bool get isAdmin {
    final user = FirebaseAuth.instance.currentUser;
    return user != null && user.email?.toLowerCase().trim() == adminEmail.toLowerCase().trim();
  }

  // --- ADD MODERATOR DIALOG ---
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
              _buildTextField(emailC, "Moderator Email"),
              const SizedBox(height: 10),
              _buildTextField(nameC, "Name"),
              const SizedBox(height: 10),
              _buildTextField(scheduleIdC, "Schedule ID (Doc ID)"),
              const SizedBox(height: 10),
              _buildTextField(scheduleTitleC, "Exam Name"),
              const SizedBox(height: 10),
              _buildTextField(commissionC, "Commission (₹)", isNumber: true),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            onPressed: () async {
              if (emailC.text.isNotEmpty && scheduleIdC.text.isNotEmpty) {
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
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text("Assign", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  // --- WITHDRAWAL DIALOG ---
  void _showAddWithdrawalDialog(String docId, String name, int currentWithdrawn, int availableBalance) {
    final amountC = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Pay to $name 💸"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Balance: ₹$availableBalance", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            TextField(controller: amountC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Amount")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              int amount = int.tryParse(amountC.text.trim()) ?? 0;
              if (amount > 0 && amount <= availableBalance) {
                await FirebaseFirestore.instance.collection('moderator_assignments').doc(docId).update({
                  'totalWithdrawn': FieldValue.increment(amount), 
                  'withdrawalHistory': FieldValue.arrayUnion([{'amount': amount, 'date': DateTime.now().toIso8601String()}])
                });
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text("Pay"),
          )
        ],
      ),
    );
  }

  // --- PAYMENT HISTORY DIALOG ---
  void _showHistoryDialog(List<dynamic> history) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Payout History 📜"),
        content: SizedBox(
          width: double.maxFinite, height: 300,
          child: history.isEmpty ? const Center(child: Text("No payments yet.")) : ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, index) {
              var item = history[history.length - 1 - index];
              return ListTile(
                leading: const Icon(Icons.arrow_upward, color: Colors.red),
                title: Text("Paid: ₹${item['amount']}"),
                subtitle: Text(DateFormat('dd MMM, hh:mm a').format(DateTime.parse(item['date']))),
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
      ),
    );
  }

  // 🔥🔥 NEW: STUDENT LIST DIALOG 🔥🔥
  void _showStudentListDialog(List<QueryDocumentSnapshot> students, int commissionRate) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Students List (${students.length}) 🎓"),
        content: SizedBox(
          width: double.maxFinite,
          height: 400, // Fixed height for list
          child: students.isEmpty 
            ? const Center(child: Text("No students yet.")) 
            : ListView.builder(
                itemCount: students.length,
                itemBuilder: (context, index) {
                  var data = students[index].data() as Map<String, dynamic>;
                  
                  // Data Extract
                  String email = data['email'] ?? 'Unknown Email';
                  String displayName = data['displayName'] ?? email.split('@')[0]; // Name fallback
                  Timestamp? grantedAt = data['grantedAt'];
                  
                  String dateStr = grantedAt != null 
                      ? DateFormat('dd MMM yyyy, hh:mm a').format(grantedAt.toDate())
                      : "Unknown Date";

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: const Icon(Icons.person, color: Colors.blue),
                      ),
                      title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(email, style: const TextStyle(fontSize: 11)),
                          Text("Bought: $dateStr", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Comm.", style: TextStyle(fontSize: 10, color: Colors.grey)),
                          Text("+₹$commissionRate", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                        ],
                      ),
                    ),
                  );
                },
              ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
      ),
    );
  }

  Widget _buildTextField(TextEditingController c, String label, {bool isNumber = false}) {
    return TextField(controller: c, keyboardType: isNumber ? TextInputType.number : TextInputType.text, decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))));
  }

  @override
  Widget build(BuildContext context) {
    if (!isAdmin) return const Scaffold(body: Center(child: Text("Access Denied")));

    return Scaffold(
      appBar: AppBar(title: const Text("Manage Moderators 👥"), backgroundColor: Colors.white, foregroundColor: Colors.black),
      floatingActionButton: FloatingActionButton(onPressed: _showAddModeratorDialog, backgroundColor: Colors.deepPurple, child: const Icon(Icons.add)),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('moderator_assignments').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
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
              
              Timestamp modJoinedAt = data['createdAt'] ?? Timestamp.now(); 

              // 🔥 Fetch Valid Students
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('study_schedules')
                    .doc(scheduleId)
                    .collection('allowed_users')
                    .where('grantedAt', isGreaterThanOrEqualTo: modJoinedAt)
                    .snapshots(),
                builder: (context, userSnap) {
                  
                  int studentCount = 0;
                  List<QueryDocumentSnapshot> studentDocs = [];

                  if (userSnap.hasData) {
                    studentDocs = userSnap.data!.docs;
                    studentCount = studentDocs.length;
                  }

                  int totalEarnings = studentCount * commission;
                  int availableBalance = totalEarnings - totalWithdrawn;

                  return Card(
                    elevation: 3, margin: const EdgeInsets.only(bottom: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(modName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                Text("Joined: ${DateFormat('dd MMM yy').format(modJoinedAt.toDate())}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                Text(data['scheduleTitle'] ?? '', style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
                              ]),
                              IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => FirebaseFirestore.instance.collection('moderator_assignments').doc(doc.id).delete())
                            ],
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _infoCol("Students", "$studentCount"),
                              _infoCol("Rate", "₹$commission"),
                              _infoCol("Earned", "₹$totalEarnings", color: Colors.blue),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _infoCol("Paid", "₹$totalWithdrawn", color: Colors.red),
                              _infoCol("Balance", "₹$availableBalance", color: Colors.green, isBold: true),
                            ],
                          ),
                          const SizedBox(height: 15),
                          
                          // 🔥 ACTION BUTTONS ROW
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // 1. History
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.history, size: 16), 
                                  label: const Text("History"), 
                                  onPressed: () => _showHistoryDialog(history)
                                ),
                                const SizedBox(width: 8),
                                
                                // 2. 🔥 NEW: View Students Button
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade50, foregroundColor: Colors.blue, elevation: 0),
                                  icon: const Icon(Icons.people, size: 16),
                                  label: const Text("Students"),
                                  onPressed: () => _showStudentListDialog(studentDocs, commission),
                                ),
                                const SizedBox(width: 8),

                                // 3. Pay Cash
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                  icon: const Icon(Icons.attach_money, size: 16),
                                  label: const Text("Pay"),
                                  onPressed: () => _showAddWithdrawalDialog(doc.id, modName, totalWithdrawn, availableBalance)
                                ),
                              ],
                            ),
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

  Widget _infoCol(String label, String value, {Color color = Colors.black, bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        Text(value, style: TextStyle(fontSize: isBold ? 20 : 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
