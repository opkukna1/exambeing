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
  final String adminEmail = "opsiddh42@gmail.com";

  bool get isAdmin {
    final user = FirebaseAuth.instance.currentUser;
    return user != null && user.email?.toLowerCase().trim() == adminEmail.toLowerCase().trim();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text("Please Login")));

    // 🔥 MAIN SWITCH: Admin vs Moderator
    if (isAdmin) {
      return _buildAdminView();
    } else {
      return _buildModeratorView(user);
    }
  }

  // ==========================================
  // 👮 ADMIN VIEW (Manage Everything)
  // ==========================================
  Widget _buildAdminView() {
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
              return _buildModeratorCard(doc.id, data, forAdmin: true);
            },
          );
        },
      ),
    );
  }

  // ==========================================
  // 🧑‍🏫 MODERATOR VIEW (Personal Dashboard)
  // ==========================================
  Widget _buildModeratorView(User user) {
    return Scaffold(
      appBar: AppBar(title: const Text("Partner Dashboard 🚀"), backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
      body: StreamBuilder<QuerySnapshot>(
        // 🔥 SIRF APNA DATA LAO
        stream: FirebaseFirestore.instance
            .collection('moderator_assignments')
            .where('moderatorEmail', isEqualTo: user.email!.trim().toLowerCase())
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.person_off, size: 60, color: Colors.grey), 
              const SizedBox(height: 10),
              const Text("You are not a Partner yet."),
              Text("Logged in as: ${user.email}", style: const TextStyle(fontSize: 12, color: Colors.grey))
            ]));
          }

          // Moderator ka data mil gaya
          var doc = snapshot.data!.docs.first;
          var data = doc.data() as Map<String, dynamic>;
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _buildModeratorCard(doc.id, data, forAdmin: false),
          );
        },
      ),
    );
  }

  // ==========================================
  // 🧩 COMMON CARD LOGIC (Used by Both)
  // ==========================================
  Widget _buildModeratorCard(String docId, Map<String, dynamic> data, {required bool forAdmin}) {
    String modName = data['moderatorName'] ?? 'Unknown';
    String scheduleId = data['scheduleId'] ?? '';
    String scheduleTitle = data['scheduleTitle'] ?? '';
    int commission = data['commissionPrice'] ?? 0;
    int totalWithdrawn = data['totalWithdrawn'] ?? 0;
    List history = data['withdrawalHistory'] ?? [];
    Timestamp modJoinedAt = data['createdAt'] ?? Timestamp.now(); 

    // 🔥 CORE EARNING LOGIC (Sub-collection Query)
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('study_schedules')
          .doc(scheduleId)
          .collection('allowed_users')
          .where('grantedAt', isGreaterThanOrEqualTo: modJoinedAt) // Date Filter
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
          elevation: 4, margin: const EdgeInsets.only(bottom: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(forAdmin ? modName : scheduleTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        if(forAdmin) Text(scheduleTitle, style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
                        if(!forAdmin) Text("Commission: ₹$commission / student", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        if(forAdmin) Text("Joined: ${DateFormat('dd MMM yy').format(modJoinedAt.toDate())}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ]),
                    ),
                    if (forAdmin) 
                      Row(children: [
                        IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showEditModeratorDialog(docId, scheduleId, scheduleTitle, commission)),
                        IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => FirebaseFirestore.instance.collection('moderator_assignments').doc(docId).delete()),
                      ]),
                  ],
                ),
                const Divider(),

                // Stats Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _infoCol("Students", "$studentCount"),
                    _infoCol("Earned", "₹$totalEarnings", color: Colors.blue),
                    _infoCol(forAdmin ? "Paid" : "Received", "₹$totalWithdrawn", color: Colors.orange),
                  ],
                ),
                const SizedBox(height: 15),

                // Balance Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green)),
                  child: Center(child: Text("Pending Payout: ₹$availableBalance", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green))),
                ),
                const SizedBox(height: 15),

                // Buttons
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      OutlinedButton.icon(icon: const Icon(Icons.history, size: 16), label: const Text("History"), onPressed: () => _showHistoryDialog(history)),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade50, foregroundColor: Colors.blue, elevation: 0), icon: const Icon(Icons.people, size: 16), label: const Text("Students"), onPressed: () => _showStudentListDialog(studentDocs, commission)),
                      if (forAdmin) ...[
                        const SizedBox(width: 8),
                        ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), icon: const Icon(Icons.attach_money, size: 16), label: const Text("Pay"), onPressed: () => _showAddWithdrawalDialog(docId, modName, totalWithdrawn, availableBalance)),
                      ]
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

  // ==========================================
  // 🛠️ DIALOGS & HELPERS (Add, Edit, List)
  // ==========================================

  void _showAddModeratorDialog() {
    final emailC = TextEditingController(); final nameC = TextEditingController(); final scheduleIdC = TextEditingController(); final scheduleTitleC = TextEditingController(); final commissionC = TextEditingController();
    showDialog(context: context, builder: (c) => AlertDialog(title: const Text("Assign Moderator"), content: SingleChildScrollView(child: Column(children: [_tf(emailC, "Email"), _tf(nameC, "Name"), _tf(scheduleIdC, "Schedule ID"), _tf(scheduleTitleC, "Exam Name"), _tf(commissionC, "Commission", isNum: true)])), actions: [TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("Cancel")), ElevatedButton(onPressed: () async {
      if(emailC.text.isNotEmpty && scheduleIdC.text.isNotEmpty) {
        await FirebaseFirestore.instance.collection('moderator_assignments').add({
          'moderatorEmail': emailC.text.trim().toLowerCase(), 'moderatorName': nameC.text.trim(), 'scheduleId': scheduleIdC.text.trim(), 'scheduleTitle': scheduleTitleC.text.trim(), 'commissionPrice': int.tryParse(commissionC.text.trim())??0, 'totalWithdrawn': 0, 'withdrawalHistory': [], 'createdAt': FieldValue.serverTimestamp()
        }); Navigator.pop(c);
      }
    }, child: const Text("Assign"))]));
  }

  void _showEditModeratorDialog(String docId, String sId, String title, int comm) {
    final sIdC = TextEditingController(text: sId); final titleC = TextEditingController(text: title); final commC = TextEditingController(text: comm.toString());
    showDialog(context: context, builder: (c) => AlertDialog(title: const Text("Edit Details"), content: Column(mainAxisSize: MainAxisSize.min, children: [_tf(sIdC, "Schedule ID"), _tf(titleC, "Exam Name"), _tf(commC, "Commission", isNum: true)]), actions: [TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("Cancel")), ElevatedButton(onPressed: () async {
      await FirebaseFirestore.instance.collection('moderator_assignments').doc(docId).update({'scheduleId': sIdC.text.trim(), 'scheduleTitle': titleC.text.trim(), 'commissionPrice': int.tryParse(commC.text.trim())??0}); Navigator.pop(c);
    }, child: const Text("Update"))]));
  }

  void _showAddWithdrawalDialog(String docId, String name, int withdrawn, int balance) {
    final amtC = TextEditingController();
    showDialog(context: context, builder: (c) => AlertDialog(title: Text("Pay to $name"), content: Column(mainAxisSize: MainAxisSize.min, children: [Text("Balance: ₹$balance", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)), _tf(amtC, "Amount", isNum: true)]), actions: [TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("Cancel")), ElevatedButton(onPressed: () async {
      int amt = int.tryParse(amtC.text.trim())??0;
      if(amt > 0 && amt <= balance) { await FirebaseFirestore.instance.collection('moderator_assignments').doc(docId).update({'totalWithdrawn': FieldValue.increment(amt), 'withdrawalHistory': FieldValue.arrayUnion([{'amount': amt, 'date': DateTime.now().toIso8601String()}])}); Navigator.pop(c); }
    }, child: const Text("Pay"))]));
  }

  void _showHistoryDialog(List history) {
    showDialog(context: context, builder: (c) => AlertDialog(title: const Text("History"), content: SizedBox(width: double.maxFinite, height: 300, child: history.isEmpty ? const Center(child: Text("No history")) : ListView.builder(itemCount: history.length, itemBuilder: (c, i) { var item = history[history.length-1-i]; return ListTile(leading: const Icon(Icons.check, color: Colors.green), title: Text("₹${item['amount']}"), subtitle: Text(DateFormat('dd MMM hh:mm a').format(DateTime.parse(item['date']))));})), actions: [TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("Close"))]));
  }

  void _showStudentListDialog(List<QueryDocumentSnapshot> students, int rate) {
    showDialog(context: context, builder: (c) => AlertDialog(title: Text("Students (${students.length})"), content: SizedBox(width: double.maxFinite, height: 400, child: students.isEmpty ? const Center(child: Text("No students")) : ListView.builder(itemCount: students.length, itemBuilder: (c, i) { var data = students[i].data() as Map<String, dynamic>; return ListTile(title: Text(data['displayName']??'User'), subtitle: Text(data['email']??''), trailing: Text("+₹$rate", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)));})), actions: [TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("Close"))]));
  }

  Widget _tf(TextEditingController c, String label, {bool isNum = false}) {
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: c, keyboardType: isNum ? TextInputType.number : TextInputType.text, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder())));
  }

  Widget _infoCol(String l, String v, {Color color = Colors.black}) {
    return Column(children: [Text(v, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)), Text(l, style: const TextStyle(fontSize: 12, color: Colors.grey))]);
  }
}
