import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async'; // Timer aur Microtask ke liye

class ManageModeratorScreen extends StatefulWidget {
  const ManageModeratorScreen({super.key});

  @override
  State<ManageModeratorScreen> createState() => _ManageModeratorScreenState();
}

class _ManageModeratorScreenState extends State<ManageModeratorScreen> {
  // 🔥 ADMIN EMAIL (Sirf isko sab dikhega)
  final String adminEmail = "opsiddh42@gmail.com";

  bool get isAdmin {
    final user = FirebaseAuth.instance.currentUser;
    return user != null && user.email?.toLowerCase().trim() == adminEmail.toLowerCase().trim();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text("Please Login")));

    // 🔥 SECURITY CHECK:
    if (isAdmin) {
      return _buildAdminView(); // Admin ko sab dikhao
    } else {
      return _buildModeratorView(user); // Moderator ko sirf apna dikhao
    }
  }

  // ==========================================
  // 👮 ADMIN VIEW (Ye Calculation karega aur DB update karega)
  // ==========================================
  Widget _buildAdminView() {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage Moderators 👥"), backgroundColor: Colors.white, foregroundColor: Colors.black),
      floatingActionButton: FloatingActionButton(onPressed: _showAddModeratorDialog, backgroundColor: Colors.deepPurple, child: const Icon(Icons.add)),
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
              // Admin ke liye "Sync Card" jo data update karega
              return _buildAdminSyncCard(doc.id, data);
            },
          );
        },
      ),
    );
  }

  // ==========================================
  // 🧑‍🏫 MODERATOR VIEW (Sirf Apna Data Padhega)
  // ==========================================
  Widget _buildModeratorView(User user) {
    return Scaffold(
      appBar: AppBar(title: const Text("Partner Dashboard 🚀"), backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
      body: StreamBuilder<QuerySnapshot>(
        // 🔒 STRICT FILTER: Sirf wahi data lao jisme 'moderatorEmail' login user ke barabar ho
        stream: FirebaseFirestore.instance
            .collection('moderator_assignments')
            .where('moderatorEmail', isEqualTo: user.email!.trim().toLowerCase()) 
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          // Agar koi assignment nahi mila
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.lock_outline, size: 60, color: Colors.grey), 
              const SizedBox(height: 10),
              const Text("Access Restricted."),
              Text("Logged in as: ${user.email}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ]));
          }

          var doc = snapshot.data!.docs.first;
          var data = doc.data() as Map<String, dynamic>;
          
          // Moderator ke liye "Read Only Card" (No Calculation, No Risk)
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _buildModeratorReadCard(doc.id, data),
          );
        },
      ),
    );
  }

  // ==========================================
  // 🔄 ADMIN CARD (With AUTO-SYNC Logic)
  // ==========================================
  Widget _buildAdminSyncCard(String docId, Map<String, dynamic> data) {
    String modName = data['moderatorName'] ?? 'Unknown';
    String scheduleId = (data['scheduleId'] ?? '').toString().trim();
    String scheduleTitle = data['scheduleTitle'] ?? '';
    int commission = data['commissionPrice'] ?? 0;
    int totalWithdrawn = data['totalWithdrawn'] ?? 0;
    List history = data['withdrawalHistory'] ?? [];
    
    // Database mein saved values (Check karne ke liye)
    int savedStudentCount = data['studentCount'] ?? 0;
    int savedTotalEarnings = data['totalEarnings'] ?? 0;

    // 🔥 ADMIN LIVE CALCULATION KAREGA
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('study_schedules')
          .doc(scheduleId)
          .collection('allowed_users')
          // Koi Date Filter nahi - Sab count honge
          .snapshots(),
      builder: (context, userSnap) {
        
        int liveStudentCount = 0;
        if (userSnap.hasData) {
          liveStudentCount = userSnap.data!.docs.length;
        }

        int liveTotalEarnings = liveStudentCount * commission;
        int liveAvailableBalance = liveTotalEarnings - totalWithdrawn;

        // ⚡ AUTO-SYNC: Agar Naya Data aaya hai, to Database update kar do
        if (liveStudentCount != savedStudentCount || liveTotalEarnings != savedTotalEarnings) {
          // Future.microtask se crash nahi hoga
          Future.microtask(() {
             FirebaseFirestore.instance.collection('moderator_assignments').doc(docId).update({
               'studentCount': liveStudentCount,
               'totalEarnings': liveTotalEarnings,
               'lastUpdated': FieldValue.serverTimestamp(),
             });
          });
        }

        return Card(
          elevation: 4, margin: const EdgeInsets.only(bottom: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(modName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(scheduleTitle, style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
                        const Text("⚡ Auto-Syncing for Partner", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                    Row(children: [
                      IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showEditModeratorDialog(docId, scheduleId, scheduleTitle, commission)),
                      IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => FirebaseFirestore.instance.collection('moderator_assignments').doc(docId).delete()),
                    ]),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _infoCol("Students", "$liveStudentCount"),
                    _infoCol("Earned", "₹$liveTotalEarnings", color: Colors.blue),
                    _infoCol("Paid", "₹$totalWithdrawn", color: Colors.orange),
                  ],
                ),
                const SizedBox(height: 15),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green)),
                  child: Center(child: Text("Pending Payout: ₹$liveAvailableBalance", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green))),
                ),
                const SizedBox(height: 15),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      OutlinedButton.icon(icon: const Icon(Icons.history, size: 16), label: const Text("History"), onPressed: () => _showHistoryDialog(history)),
                      const SizedBox(width: 8),
                      // Admin can see students list
                      ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade50, foregroundColor: Colors.blue, elevation: 0), icon: const Icon(Icons.people, size: 16), label: const Text("Students"), onPressed: () {
                          if (userSnap.hasData) _showStudentListDialog(userSnap.data!.docs, commission);
                      }),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), icon: const Icon(Icons.attach_money, size: 16), label: const Text("Pay"), onPressed: () => _showAddWithdrawalDialog(docId, modName, totalWithdrawn, liveAvailableBalance)),
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
  // 👁️ MODERATOR CARD (Simple Read-Only)
  // ==========================================
  Widget _buildModeratorReadCard(String docId, Map<String, dynamic> data) {
    String scheduleTitle = data['scheduleTitle'] ?? '';
    int commission = data['commissionPrice'] ?? 0;
    int totalWithdrawn = data['totalWithdrawn'] ?? 0;
    List history = data['withdrawalHistory'] ?? [];

    // 🔥 MODERATOR BAS DATABASE PADHEGA (No Calculation)
    int studentCount = data['studentCount'] ?? 0;
    int totalEarnings = data['totalEarnings'] ?? 0;
    int availableBalance = totalEarnings - totalWithdrawn;

    return Card(
      elevation: 4, margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(scheduleTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text("Commission: ₹$commission / student", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
                  child: const Text("Verified ✅", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                )
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _infoCol("Students", "$studentCount"),
                _infoCol("Earned", "₹$totalEarnings", color: Colors.blue),
                _infoCol("Received", "₹$totalWithdrawn", color: Colors.orange),
              ],
            ),
            const SizedBox(height: 15),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green)),
              child: Center(child: Text("Pending Payout: ₹$availableBalance", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green))),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.history), 
                    label: const Text("History"), 
                    onPressed: () => _showHistoryDialog(history)
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 🛠️ DIALOGS
  // ==========================================

  void _showAddModeratorDialog() {
    final emailC = TextEditingController(); final nameC = TextEditingController(); final scheduleIdC = TextEditingController(); final scheduleTitleC = TextEditingController(); final commissionC = TextEditingController();
    showDialog(context: context, builder: (c) => AlertDialog(title: const Text("Assign Moderator"), content: SingleChildScrollView(child: Column(children: [_tf(emailC, "Email"), _tf(nameC, "Name"), _tf(scheduleIdC, "Schedule ID"), _tf(scheduleTitleC, "Exam Name"), _tf(commissionC, "Commission", isNum: true)])), actions: [TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("Cancel")), ElevatedButton(onPressed: () async {
      if(emailC.text.isNotEmpty && scheduleIdC.text.isNotEmpty) {
        await FirebaseFirestore.instance.collection('moderator_assignments').add({
          'moderatorEmail': emailC.text.trim().toLowerCase(), 'moderatorName': nameC.text.trim(), 'scheduleId': scheduleIdC.text.trim(), 'scheduleTitle': scheduleTitleC.text.trim(), 'commissionPrice': int.tryParse(commissionC.text.trim())??0, 'totalWithdrawn': 0, 'withdrawalHistory': [], 'studentCount': 0, 'totalEarnings': 0, 'createdAt': FieldValue.serverTimestamp()
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
    showDialog(context: context, builder: (c) => AlertDialog(title: Text("Students (${students.length})"), content: SizedBox(width: double.maxFinite, height: 400, child: students.isEmpty ? const Center(child: Text("No students yet.")) : ListView.builder(itemCount: students.length, itemBuilder: (c, i) { var data = students[i].data() as Map<String, dynamic>; return ListTile(title: Text(data['displayName']??'User'), subtitle: Text(data['email']??''), trailing: Text("+₹$rate", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)));})), actions: [TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("Close"))]));
  }

  Widget _tf(TextEditingController c, String label, {bool isNum = false}) {
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: c, keyboardType: isNum ? TextInputType.number : TextInputType.text, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder())));
  }

  Widget _infoCol(String l, String v, {Color color = Colors.black}) {
    return Column(children: [Text(v, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)), Text(l, style: const TextStyle(fontSize: 12, color: Colors.grey))]);
  }
}
