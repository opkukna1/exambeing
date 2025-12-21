import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/test_model.dart';
import 'attempt_test_screen.dart';
import 'solutions_screen.dart';
// 🔥 Ensure imports are correct
import '../../admin/screens/create_test_screen.dart';
import '../../admin/screens/manage_users_screen.dart'; 

class TestListScreen extends StatelessWidget {
  // 🔥 IDs required for Nested Path
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

    // 1. User Role Check Stream
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, userSnapshot) {
        
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
          
          // 🔥 Add Test Button (Only for Host)
          // Passes IDs to Create Screen so test is created in correct week
          floatingActionButton: isHost
              ? FloatingActionButton.extended(
                  onPressed: () {
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

          // 🔥 LOAD TESTS (From Nested Path)
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
                  
                  // Logic Variables
                  String creatorId = data['createdBy'] ?? '';
                  String contactNum = data['contactNumber'] ?? '8005576670';
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
                          
                          // 🔥 Decide Buttons (Teacher vs Student)
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

  // 🛡️ SECURITY CHECK FOR STUDENTS
  Future<void> _checkAccessAndStart(BuildContext context, TestModel test, User user, String contactNum) async {
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));

    try {
      String emailKey = user.email!.trim().toLowerCase();
      
      // 🔥 CRITICAL: Checking Nested Collection
      DocumentSnapshot permDoc = await FirebaseFirestore.instance
          .collection('study_schedules').doc(examId)
          .collection('weeks').doc(weekId)
          .collection('tests').doc(test.id)
          .collection('allowed_users').doc(emailKey)
          .get();

      // ❌ 1. Not in Allowed List -> Popup
      if (!permDoc.exists) {
        if (context.mounted) {
          Navigator.pop(context); // Close Loader
          _showPurchasePopup(context, contactNum); // Show Contact Popup
        }
        return;
      }

      // ❌ 2. Expired Check
      DateTime expiryDate = (permDoc['expiryDate'] as Timestamp).toDate();
      if (DateTime.now().isAfter(expiryDate)) {
        throw "Access Expired on ${_formatDate(expiryDate)}.";
      }

      // ✅ 3. Allowed -> Go to Test
      if (context.mounted) {
        Navigator.pop(context);
        Navigator.push(
          context, 
          MaterialPageRoute(builder: (_) => AttemptTestScreen(
             testId: test.id,
             testData: { 
               'testTitle': test.subject,
               'questions': test.questions,
               'settings': {} 
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

  // 💰 POPUP UI
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
              const Text("Is test ko attempt karne ke liye aapko teacher se access lena hoga.", style: TextStyle(fontSize: 14)),
              const SizedBox(height: 15),
              const Text("Contact Teacher to Subscribe:", style: TextStyle(fontSize: 12, color: Colors.grey)),
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

  // 🔘 BUTTON LOGIC
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

    // ✅ TEACHER VIEW (Uses Nested IDs)
    if (isHost && isMyTest) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.group_add, color: Colors.blue),
            tooltip: "Manage Students",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ManageUsersScreen(
                  testId: test.id, 
                  testName: data['testTitle'] ?? test.subject,
                  examId: examId, // Passing ID
                  weekId: weekId, // Passing ID
                )),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () async {
               bool confirm = await showDialog(context: context, builder: (c) => AlertDialog(title: const Text("Delete Test?"), actions: [TextButton(onPressed: ()=>Navigator.pop(c,false), child: const Text("No")), TextButton(onPressed: ()=>Navigator.pop(c,true), child: const Text("Yes"))])) ?? false;
               if(confirm) {
                   // Delete from Nested Path
                   await FirebaseFirestore.instance.collection('study_schedules').doc(examId).collection('weeks').doc(weekId).collection('tests').doc(test.id).delete();
               }
            },
          ),
        ],
      );
    }
    
    // Other Teacher
    if (isHost && !isMyTest) return const Text("Locked", style: TextStyle(fontSize: 10, color: Colors.grey));

    // Student: Result
    if (isAttempted) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SolutionsScreen(testId: test.id, originalQuestions: test.questions))),
        child: const Text("Result"),
      );
    }

    // Student: Time Lock
    if (isLocked) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Starts at ${_formatDate(test.scheduledAt)}"))),
        child: const Text("Locked"),
      );
    }

    // Student: Start (Runs Security Check)
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
      onPressed: () => _checkAccessAndStart(context, test, user, contactNum),
      child: const Text("Start"),
    );
  }
}
