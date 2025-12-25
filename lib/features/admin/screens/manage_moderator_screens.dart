import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class ManageModeratorScreen extends StatefulWidget {
  const ManageModeratorScreen({super.key});

  @override
  State<ManageModeratorScreen> createState() => _ManageModeratorScreenState();
}

class _ManageModeratorScreenState extends State<ManageModeratorScreen> {
  // 🔥 ADMIN EMAIL
  final String adminEmail = "opsiddh42@gmail.com";

  bool get isAdmin {
    final user = FirebaseAuth.instance.currentUser;
    return user != null && user.email?.toLowerCase().trim() == adminEmail.toLowerCase().trim();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text("Please Login")));

    // 🔀 LOGIC: Admin hai to Feeder Panel, Moderator hai to Reader Dashboard
    if (isAdmin) {
      return _buildAdminPanel();
    } else {
      return _buildModeratorDashboard(user);
    }
  }

  // ==========================================
  // 👮 ADMIN PANEL (The Calculation Engine ⚙️)
  // ==========================================
  Widget _buildAdminPanel() {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage & Sync 📡"), backgroundColor: Colors.white, foregroundColor: Colors.black),
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
              
              // 🔥 HAR MODERATOR KE LIYE ALAG CALCULATION CHALEGI
              return _AdminFeederCard(
                docId: doc.id, 
                data: data, 
                onEdit: _showEditModeratorDialog, 
                onPay: _showAddWithdrawalDialog
              );
            },
          );
        },
      ),
    );
  }

  // ==========================================
  // 🚀 MODERATOR DASHBOARD (Only Reader 📖)
  // ==========================================
  Widget _buildModeratorDashboard(User user) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Dashboard 📊"), backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
      body: StreamBuilder<QuerySnapshot>(
        // 🔥 Sirf Apne Email Wala Assignment Padho
        stream: FirebaseFirestore.instance
            .collection('moderator_assignments')
            .where('moderatorEmail', isEqualTo: user.email!.trim().toLowerCase()) 
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.lock_clock, size: 60, color: Colors.grey),
              const SizedBox(height: 10),
              const Text("No Assignment Found."),
              Text("ID: ${user.email}", style: const TextStyle(color: Colors.grey)),
            ]));
          }

          var data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
          
          // 🔥 KOI CALCULATION NAHI - BAS DATA DIKHAO
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _ModeratorViewCard(data: data),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------
  // 🛠️ DIALOGS (Add, Edit, Pay)
  // ---------------------------------------------------
  void _showAddModeratorDialog() {
    final emailC = TextEditingController(); final nameC = TextEditingController(); final scheduleIdC = TextEditingController(); final scheduleTitleC = TextEditingController(); final commissionC = TextEditingController();
    showDialog(context: context, builder: (c) => AlertDialog(title: const Text("Assign New"), content: SingleChildScrollView(child: Column(children: [_tf(emailC, "Email (Small letters)"), _tf(nameC, "Name"), _tf(scheduleIdC, "Schedule ID (Exact)"), _tf(scheduleTitleC, "Exam Name"), _tf(commissionC, "Commission Rate", isNum: true)])), actions: [TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("Cancel")), ElevatedButton(onPressed: () async {
      if(emailC.text.isNotEmpty && scheduleIdC.text.isNotEmpty) {
        // Initial Data Feed (0 values)
        await FirebaseFirestore.instance.collection('moderator_assignments').add({
          'moderatorEmail': emailC.text.trim().toLowerCase(), 'moderatorName': nameC.text.trim(), 'scheduleId': scheduleIdC.text.trim(), 'scheduleTitle': scheduleTitleC.text.trim(), 'commissionPrice': int.tryParse(commissionC.text.trim())??0, 
          'totalWithdrawn': 0, 'withdrawalHistory': [], 
          'studentCount': 0, 'totalEarnings': 0, // 🔥 Feeder Fields (Shuru me 0)
          'lastSynced': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp() // Is time ke baad wale students count honge
        }); Navigator.pop(c);
      }
    }, child: const Text("Assign"))]));
  }

  void _showEditModeratorDialog(String docId, String sId, String title, int comm) {
    final sIdC = TextEditingController(text: sId); final titleC = TextEditingController(text: title); final commC = TextEditingController(text: comm.toString());
    showDialog(context: context, builder: (c) => AlertDialog(title: const Text("Edit"), content: Column(mainAxisSize: MainAxisSize.min, children: [_tf(sIdC, "Schedule ID"), _tf(titleC, "Exam Name"), _tf(commC, "Commission", isNum: true)]), actions: [TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("Cancel")), ElevatedButton(onPressed: () async {
      await FirebaseFirestore.instance.collection('moderator_assignments').doc(docId).update({'scheduleId': sIdC.text.trim(), 'scheduleTitle': titleC.text.trim(), 'commissionPrice': int.tryParse(commC.text.trim())??0}); Navigator.pop(c);
    }, child: const Text("Update"))]));
  }

  void _showAddWithdrawalDialog(String docId, String name, int withdrawn, int balance) {
    final amtC = TextEditingController();
    showDialog(context: context, builder: (c) => AlertDialog(title: Text("Pay $name"), content: Column(mainAxisSize: MainAxisSize.min, children: [Text("Available: ₹$balance", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)), _tf(amtC, "Amount", isNum: true)]), actions: [TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("Cancel")), ElevatedButton(onPressed: () async {
      int amt = int.tryParse(amtC.text.trim())??0;
      if(amt > 0 && amt <= balance) { await FirebaseFirestore.instance.collection('moderator_assignments').doc(docId).update({'totalWithdrawn': FieldValue.increment(amt), 'withdrawalHistory': FieldValue.arrayUnion([{'amount': amt, 'date': DateTime.now().toIso8601String()}])}); Navigator.pop(c); }
    }, child: const Text("Pay"))]));
  }

  Widget _tf(TextEditingController c, String l, {bool isNum = false}) => Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: c, keyboardType: isNum ? TextInputType.number : TextInputType.text, decoration: InputDecoration(labelText: l, border: const OutlineInputBorder())));
}

// ==========================================
// 📡 ADMIN FEEDER CARD (Specific ID + Time Filter)
// ==========================================
class _AdminFeederCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final Function onEdit;
  final Function onPay;

  const _AdminFeederCard({required this.docId, required this.data, required this.onEdit, required this.onPay});

  @override
  Widget build(BuildContext context) {
    // 1. Moderator ki Specific ID aur Time nikalo
    String scheduleId = (data['scheduleId'] ?? '').toString().trim();
    Timestamp joinedAt = data['createdAt'] ?? Timestamp.now();
    int commission = data['commissionPrice'] ?? 0;
    int totalWithdrawn = data['totalWithdrawn'] ?? 0;
    
    // DB mein abhi kya value hai?
    int dbStudentCount = data['studentCount'] ?? 0;
    int dbEarnings = data['totalEarnings'] ?? 0;

    return StreamBuilder<QuerySnapshot>(
      // 🔥 STEP 1: Sirf USI Schedule ke andar jao
      stream: FirebaseFirestore.instance
          .collection('study_schedules')
          .doc(scheduleId) 
          .collection('allowed_users')
          // 🔥 STEP 2: Time Filter Lagao (Joining Time se pehle wale count MAT karo)
          .where('grantedAt', isGreaterThanOrEqualTo: joinedAt) 
          .snapshots(),
      builder: (context, studentSnap) {
        
        // 🔥 STEP 3: Naye Students Gino
        int liveCount = 0;
        if (studentSnap.hasData) liveCount = studentSnap.data!.docs.length;
        
        // Earning Calculate Karo
        int liveEarnings = liveCount * commission;
        int liveBalance = liveEarnings - totalWithdrawn;

        // 🔥 STEP 4: Agar data naya hai, to Moderator ke Assignment mein likh do
        if (liveCount != dbStudentCount || liveEarnings != dbEarnings) {
          Future.delayed(Duration.zero, () {
            FirebaseFirestore.instance.collection('moderator_assignments').doc(docId).update({
              'studentCount': liveCount,
              'totalEarnings': liveEarnings,
              'lastSynced': FieldValue.serverTimestamp(),
            });
            debugPrint("✅ Data Sync: $liveCount students for ${data['moderatorName']}");
          });
        }

        return Card(
          elevation: 3, margin: const EdgeInsets.only(bottom: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(data['moderatorName'] ?? 'Name', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text("ID: $scheduleId", style: const TextStyle(color: Colors.deepPurple, fontSize: 12)),
                    Text("Since: ${DateFormat('dd MMM').format(joinedAt.toDate())}", style: const TextStyle(color: Colors.grey, fontSize: 10)),
                  ]),
                  Row(children: [
                    IconButton(icon: const Icon(Icons.edit, size: 20, color: Colors.blue), onPressed: () => onEdit(docId, scheduleId, data['scheduleTitle'], commission)),
                    IconButton(icon: const Icon(Icons.attach_money, size: 20, color: Colors.green), onPressed: () => onPay(docId, data['moderatorName'], totalWithdrawn, liveBalance)),
                  ])
                ]),
                const Divider(),
                Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _stat("New Students", "$liveCount"), // Ye filtered count hai
                  _stat("Earnings", "₹$liveEarnings"),
                  _stat("Paid", "₹$totalWithdrawn"),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }
  Widget _stat(String l, String v) => Column(children: [Text(v, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text(l, style: const TextStyle(fontSize: 10, color: Colors.grey))]);
}

// ==========================================
// 📖 MODERATOR VIEW CARD (Simple Reader)
// ==========================================
class _ModeratorViewCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ModeratorViewCard({required this.data});

  @override
  Widget build(BuildContext context) {
    // 🔥 MODERATOR BAS DATABASE SE PADHEGA (Jo Admin ne likha hai)
    int count = data['studentCount'] ?? 0;
    int earned = data['totalEarnings'] ?? 0;
    int withdrawn = data['totalWithdrawn'] ?? 0;
    int balance = earned - withdrawn;
    List history = data['withdrawalHistory'] ?? [];

    return Column(
      children: [
        // 1. Info Card
        Card(
          elevation: 5, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['scheduleTitle'] ?? 'Your Assignment', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                Text("Commission Rate: ₹${data['commissionPrice']}", style: TextStyle(color: Colors.grey[600])),
                const Divider(height: 30),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                   _bigStat("Students", "$count", Colors.black),
                   _bigStat("Earned", "₹$earned", Colors.blue),
                   _bigStat("Paid", "₹$withdrawn", Colors.orange),
                ]),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text("Pending Payout", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    Text("₹$balance", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
                  ]),
                )
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 20),
        
        // 2. History List
        const Align(alignment: Alignment.centerLeft, child: Text("  Payout History", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey))),
        const SizedBox(height: 10),
        history.isEmpty 
          ? const Padding(padding: EdgeInsets.all(20), child: Text("No payouts received yet."))
          : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: history.length,
              itemBuilder: (context, index) {
                var item = history[history.length - 1 - index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.check, color: Colors.white)),
                    title: Text("Received ₹${item['amount']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(item['date']))),
                  ),
                );
              },
            )
      ],
    );
  }

  Widget _bigStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
