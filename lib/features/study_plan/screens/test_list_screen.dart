import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/test_model.dart';
import 'attempt_test_screen.dart';
import 'test_solution_screen.dart'; 
import '../../admin/screens/manage_users_screen.dart'; 

class TestListScreen extends StatelessWidget {
  final String examId;
  final String weekId;
  final bool isLockedMode; // true = Demo User (Free), false = Premium User

  const TestListScreen({
    super.key, 
    required this.examId, 
    required this.weekId,
    this.isLockedMode = false, 
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text("Please Login")));

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
            // 🔥 FIX: Removed 'const' before PreferredSize because Container cannot be const
            bottom: isLockedMode && !isHost 
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(30),
                  child: Container(
                    color: Colors.orange,
                    width: double.infinity,
                    alignment: Alignment.center,
                    child: const Text("DEMO MODE: First Test Free", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                )
              : null,
            actions: [
              if (isHost)
                const Padding(
                  padding: EdgeInsets.only(right: 16.0),
                  child: Center(
                    child: Text("TEACHER", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white, backgroundColor: Colors.red))
                  ),
                )
            ],
          ),
          
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

              var docs = testSnapshot.data!.docs;

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final test = TestModel.fromMap(data, doc.id);
                  
                  String creatorId = data['createdBy'] ?? '';
                  String contactNum = data['contactNumber'] ?? '8005576670';
                  bool isMyTest = (user.uid == creatorId);

                  return StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(user.uid).collection('test_results').doc(test.id).snapshots(),
                    builder: (context, resultSnapshot) {
                      bool isAttempted = resultSnapshot.hasData && resultSnapshot.data!.exists;

                      return Card(
                        elevation: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: ListTile(
                          leading: Icon(Icons.assignment, color: isHost ? Colors.deepPurple : Colors.blue),
                          title: Row(
                            children: [
                              Expanded(child: Text(data['testTitle'] ?? test.subject, style: const TextStyle(fontWeight: FontWeight.bold))),
                              // Tag for Free Test
                              if (isLockedMode && index == 0) 
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)),
                                  child: const Text("FREE", style: TextStyle(fontSize: 10, color: Colors.white)),
                                )
                            ],
                          ),
                          subtitle: Text("Starts: ${_formatDate(test.scheduledAt)}"),
                          isThreeLine: true,
                          
                          trailing: _buildActionButtons(
                            context: context, 
                            test: test, 
                            data: data, 
                            isAttempted: isAttempted, 
                            isHost: isHost, 
                            isMyTest: isMyTest, 
                            user: user, 
                            contactNum: contactNum,
                            index: index 
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

  // 🔥 STRICT CHECK FUNCTION
  Future<void> _checkAccessAndStart(BuildContext context, TestModel test, User user, String contactNum, int index) async {
    
    // 🛑 1. SUPER STRICT LOCK CHECK
    if (isLockedMode && index > 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("🔒 Please Buy the Series to unlock this test."), backgroundColor: Colors.red));
      return; 
    }

    // 2. Show Loading
    showDialog(
      context: context, 
      barrierDismissible: false, 
      builder: (c) => const Center(child: CircularProgressIndicator())
    );

    try {
      // 🟢 Agar LockedMode hai lekin Index == 0 hai (Free Test), to DB check skip karo
      if (isLockedMode && index == 0) {
        if (context.mounted) Navigator.of(context, rootNavigator: true).pop(); // Close Loading
        _navigateToAttemptScreen(context, test);
        return;
      }

      // 🔵 Premium User Check (Database Verification)
      String emailKey = user.email!.trim().toLowerCase();
      DocumentSnapshot permDoc = await FirebaseFirestore.instance
          .collection('study_schedules').doc(examId)
          .collection('allowed_users').doc(emailKey)
          .get();

      if (context.mounted) Navigator.of(context, rootNavigator: true).pop(); // Close Loading

      if (!permDoc.exists) {
        if (context.mounted) _showPurchasePopup(context, contactNum); 
        return;
      }

      // Check Expiry
      if (permDoc.data() != null) {
        Map<String, dynamic> permData = permDoc.data() as Map<String, dynamic>;
        if (permData.containsKey('expiryDate')) {
           DateTime expiryDate = (permData['expiryDate'] as Timestamp).toDate();
           if (DateTime.now().isAfter(expiryDate)) {
             if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Access Expired on ${_formatDate(expiryDate)}"), backgroundColor: Colors.red));
             return;
           }
        }
      }

      // Success -> Navigate
      if (context.mounted) _navigateToAttemptScreen(context, test);

    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); 
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  void _navigateToAttemptScreen(BuildContext context, TestModel test) {
    List<Map<String, dynamic>> questionsAsMaps = test.questions.map((q) => q.toMap()).toList();
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => AttemptTestScreen(
          testId: test.id,
          testData: { 
            'testTitle': test.subject,
            'questions': questionsAsMaps, 
            'settings': test.settings 
          },
          examId: examId,
          weekId: weekId,
      ))
    );
  }

  void _showPurchasePopup(BuildContext context, String contact) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(children: [Icon(Icons.lock, color: Colors.red), SizedBox(width: 10), Text("Paid Test")]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("This is a Premium Test.\nPlease buy the series."),
              const SizedBox(height: 10),
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
        );
      },
    );
  }

  Widget _buildActionButtons({
    required BuildContext context, 
    required TestModel test, 
    required Map<String, dynamic> data,
    required bool isAttempted, 
    required bool isHost, 
    required bool isMyTest, 
    required User user,
    required String contactNum,
    required int index 
  }) {
    DateTime now = DateTime.now();
    bool isLockedTime = now.isBefore(test.scheduledAt);

    if (isHost && isMyTest) {
      return IconButton(
        icon: const Icon(Icons.delete, color: Colors.red),
        onPressed: () async {
            bool confirm = await showDialog(context: context, builder: (c) => AlertDialog(title: const Text("Delete Test?"), actions: [TextButton(onPressed: ()=>Navigator.pop(c,false), child: const Text("No")), TextButton(onPressed: ()=>Navigator.pop(c,true), child: const Text("Yes"))])) ?? false;
            if(confirm) await FirebaseFirestore.instance.collection('study_schedules').doc(examId).collection('weeks').doc(weekId).collection('tests').doc(test.id).delete();
        },
      );
    }
    
    if (isHost && !isMyTest) return const Text("Locked", style: TextStyle(fontSize: 10, color: Colors.grey));

    // 🔥🔥 STRICT UI LOCK 🔥🔥
    if (isLockedMode && index > 0) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade400),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("🔒 Buy Series to Unlock"), duration: Duration(seconds: 1)));
        },
        child: const Icon(Icons.lock, color: Colors.white, size: 18),
      );
    }

    if (isAttempted) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TestSolutionScreen(testId: test.id, originalQuestions: test.questions.map((q) => q.toMap()).toList()))),
        child: const Text("Result"),
      );
    }

    if (isLockedTime) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Starts at ${_formatDate(test.scheduledAt)}"))),
        child: const Text("Wait"),
      );
    }

    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
      onPressed: () => _checkAccessAndStart(context, test, user, contactNum, index), 
      child: Text(isLockedMode && index == 0 ? "Free" : "Start"),
    );
  }
}
