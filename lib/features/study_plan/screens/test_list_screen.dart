import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/test_model.dart';
import 'attempt_test_screen.dart';
import 'solutions_screen.dart';
import '../../admin/screens/create_test_screen.dart';
import '../../admin/screens/manage_users_screen.dart'; 

class TestListScreen extends StatelessWidget {
  // 🔥 ये IDs बहुत जरूरी हैं ताकि सही जगह से डाटा मिले
  final String examId;
  final String weekId;

  const TestListScreen({
    Key? key, 
    required this.examId, 
    required this.weekId
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text("Please Login")));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, userSnapshot) {
        
        // 1. Host Check
        bool isHost = false;
        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          if (userData['host'].toString().toLowerCase() == 'yes') isHost = true;
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text("Scheduled Tests"),
            actions: [
              if (isHost)
                const Padding(
                  padding: EdgeInsets.only(right: 16.0),
                  child: Center(
                    child: Text(
                      "TEACHER MODE", 
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white, backgroundColor: Colors.red)
                    )
                  ),
                )
            ],
          ),
          
          // Add Test Button (Sirf Host ko dikhega)
          floatingActionButton: isHost
              ? FloatingActionButton.extended(
                  onPressed: () {
                    // 🔥 Pass IDs to Create Screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => CreateTestScreen(examId: examId, weekId: weekId)),
                    );
                  },
                  label: const Text("Add Test"),
                  icon: const Icon(Icons.add),
                  backgroundColor: Colors.deepPurple,
                )
              : null,

          // 🔥 FIXED: Load Tests from NESTED Collection (Schedule -> Week -> Tests)
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('study_schedules').doc(examId)
                .collection('weeks').doc(weekId)
                .collection('tests')
                .orderBy('scheduledAt', descending: true)
                .snapshots(),
            builder: (context, testSnapshot) {
              if (testSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!testSnapshot.hasData || testSnapshot.data!.docs.isEmpty) {
                return const Center(child: Text("No tests scheduled yet."));
              }

              return ListView.builder(
                itemCount: testSnapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = testSnapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final test = TestModel.fromMap(data, doc.id);
                  
                  // 🔥 Variables
                  String creatorId = data['createdBy'] ?? '';
                  String contactNum = data['contactNumber'] ?? '8005576670'; // Default backup
                  bool isMyTest = (user.uid == creatorId);

                  // Check Attempt Status
                  return StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(user.uid).collection('test_results').doc(test.id).snapshots(),
                    builder: (context, resultSnapshot) {
                      bool isAttempted = resultSnapshot.hasData && resultSnapshot.data!.exists;

                      return Card(
                        elevation: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: ListTile(
                          leading: Icon(Icons.assignment, color: isHost ? Colors.deepPurple : Colors.blue),
                          title: Text(data['testTitle'] ?? test.subject, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("Starts: ${_formatDate(test.scheduledAt)}"),
                          isThreeLine: true,
                          
                          // 🔥 Action Buttons
                          trailing: _buildActionButtons(
                            context: context, 
                            test: test, 
                            data: data,
                            isAttempted: isAttempted, 
                            isHost: isHost, 
                            isMyTest: isMyTest, 
                            user: user,
                            contactNum: contactNum
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
      },
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month} - ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }

  // 🛡️ SECURITY CHECK (Using Correct Path)
  Future<void> _checkAccessAndStart(BuildContext context, TestModel test, User user, String contactNum) async {
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));

    try {
      String emailKey = user.email!.trim().toLowerCase();
      
      // 🔥 FIX: Verify in Nested Collection (Schedule -> Week -> Tests -> AllowedUsers)
      DocumentSnapshot permDoc = await FirebaseFirestore.instance
          .collection('study_schedules').doc(examId)
          .collection('weeks').doc(weekId)
          .collection('tests').doc(test.id)
          .collection('allowed_users').doc(emailKey)
          .get();

      // ❌ Not Allowed -> Show Purchase Popup
      if (!permDoc.exists) {
        if (context.mounted) {
          Navigator.pop(context); // Close Loader
          _showPurchasePopup(context, contactNum); // Show Popup
        }
        return;
      }

      // ❌ Expired Check
      DateTime expiryDate = (permDoc['expiryDate'] as Timestamp).toDate();
      if (DateTime.now().isAfter(expiryDate)) {
        throw "Access Expired on ${_formatDate(expiryDate)}.";
      }

      // ✅ Allowed -> Start Test
      if (context.mounted) {
        Navigator.pop(context);
        Navigator.push(
          context, 
          MaterialPageRoute(builder: (_) => AttemptTestScreen(
             testId: test.id,
             testData: { 
               'testTitle': test.subject,
               'questions': test.questions,
               'settings': {} // Agar settings test model me hain to pass karein
             },
             examId: examId,
             weekId: weekId,
          ))
        );
      }

    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    }
  }

  // 💰 PURCHASE POPUP
  void _showPurchasePopup(BuildContext context, String contact) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [Icon(Icons.lock, color: Colors.red), SizedBox(width: 10), Text("Paid Test")]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Is test ko attempt karne ke liye aapko Subscription lena hoga.", style: TextStyle(fontSize: 14)),
              const SizedBox(height: 15),
              const Text("Subscribe karne ke liye Teacher se contact karein:", style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("WhatsApp / Call", style: TextStyle(fontSize: 10, color: Colors.green)),
                        Text(contact, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.green),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: contact));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Number Copied!"), backgroundColor: Colors.green));
                      },
                    )
                  ],
                ),
              )
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            )
          ],
        );
      },
    );
  }

  // 🔘 BUTTON BUILDER
  Widget _buildActionButtons({
    required BuildContext context, 
    required TestModel test, 
    required Map<String, dynamic> data,
    required bool isAttempted, 
    required bool isHost, 
    required bool isMyTest, 
    required User user,
    required String contactNum
  }) {
    DateTime now = DateTime.now();
    bool isLocked = now.isBefore(test.scheduledAt);

    // 1. TEACHER VIEW (Agar Host hai aur Usne banaya hai)
    if (isHost && isMyTest) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 👥 Manage Users Button
          IconButton(
            icon: const Icon(Icons.group_add, color: Colors.blue),
            tooltip: "Manage Students",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ManageUsersScreen(
                  testId: test.id, 
                  testName: data['testTitle'] ?? test.subject,
                  examId: examId, // 🔥 Passing Correct IDs
                  weekId: weekId,
                )),
              );
            },
          ),
          // Delete Button
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () async {
               bool confirm = await showDialog(context: context, builder: (c) => AlertDialog(title: const Text("Delete Test?"), actions: [TextButton(onPressed: ()=>Navigator.pop(c,false), child: const Text("No")), TextButton(onPressed: ()=>Navigator.pop(c,true), child: const Text("Yes"))])) ?? false;
               if(confirm) {
                   await FirebaseFirestore.instance.collection('study_schedules').doc(examId).collection('weeks').doc(weekId).collection('tests').doc(test.id).delete();
               }
            },
          ),
        ],
      );
    }
    
    // 2. OTHER TEACHER (Locked)
    if (isHost && !isMyTest) return const Text("Locked", style: TextStyle(fontSize: 10, color: Colors.grey));

    // 3. STUDENT: Result
    if (isAttempted) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SolutionsScreen(testId: test.id, originalQuestions: test.questions))),
        child: const Text("Result"),
      );
    }

    // 4. STUDENT: Time Lock
    if (isLocked) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Starts at ${_formatDate(test.scheduledAt)}"))),
        child: const Text("Locked"),
      );
    }

    // 5. STUDENT: Start (Security Check)
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
      onPressed: () => _checkAccessAndStart(context, test, user, contactNum),
      child: const Text("Start"),
    );
  }
}
