import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/test_model.dart';
import 'attempt_test_screen.dart';
import 'solutions_screen.dart';
import '../../admin/screens/create_test_screen.dart';
import '../../admin/screens/manage_users_screen.dart'; // Manage Users Import

class TestListScreen extends StatelessWidget {
  const TestListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return const Scaffold(body: Center(child: Text("Please Login")));

    // 🔥 LEVEL 1 STREAM: Check User Role (Host or Student)
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, userSnapshot) {
        
        // 1. Determine if current user is HOST
        bool isHost = false;
        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          // Check if 'host' field exists and is 'yes'
          if (userData.containsKey('host') && userData['host'].toString().toLowerCase() == 'yes') {
            isHost = true;
          }
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text("Scheduled Tests"),
            actions: [
              if (isHost)
                const Padding(
                  padding: EdgeInsets.only(right: 18.0),
                  child: Center(
                    child: Text(
                      "HOST MODE", 
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)
                    )
                  ),
                )
            ],
          ),
          
          // 🔥 FAB: Sirf Host ko dikhega (Add Test Button)
          floatingActionButton: isHost
              ? FloatingActionButton.extended(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CreateTestScreen()),
                    );
                  },
                  label: const Text("Add Test"),
                  icon: const Icon(Icons.add),
                  backgroundColor: Colors.red,
                )
              : null,

          // 🔥 LEVEL 2 STREAM: Load Tests List
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('tests')
                .orderBy('scheduledAt', descending: true)
                .snapshots(),
            builder: (context, testSnapshot) {
              if (!testSnapshot.hasData) return const Center(child: CircularProgressIndicator());
              if (testSnapshot.data!.docs.isEmpty) return const Center(child: Text("No tests scheduled yet."));

              return ListView.builder(
                itemCount: testSnapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = testSnapshot.data!.docs[index];
                  final test = TestModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);

                  // 🔥 LEVEL 3 STREAM: Check if Student Attempted (Only relevant for UI update)
                  return StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('my_results')
                        .doc(test.id)
                        .snapshots(),
                    builder: (context, resultSnapshot) {
                      bool isAttempted = resultSnapshot.hasData && resultSnapshot.data!.exists;

                      return Card(
                        elevation: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: ListTile(
                          leading: Icon(Icons.assignment, color: isHost ? Colors.red : Colors.blue),
                          title: Text(test.subject, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("${test.topic}\n${_formatDate(test.scheduledAt)}"),
                          isThreeLine: true,
                          // Pass 'isHost' to determine which buttons to show
                          trailing: _buildActionButton(context, test, isAttempted, isHost, user),
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

  // Time format helper
  String _formatDate(DateTime date) {
    return "${date.day}/${date.month} - ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }

  // 🔒 SECURITY CHECK LOGIC FOR STUDENTS
  Future<void> _checkAccessAndStart(BuildContext context, TestModel test, User user) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // A. Check Paid Status
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!userDoc.exists) throw "User data not found.";
      
      String isPaid = (userDoc['paid_for_gold'] ?? 'no').toString().toLowerCase();
      if (isPaid != 'yes') {
        throw "Access Denied: You need a Premium Subscription.";
      }

      // B. Check Allowed List
      String emailKey = user.email!.trim().toLowerCase();
      DocumentSnapshot permDoc = await FirebaseFirestore.instance
          .collection('tests')
          .doc(test.id)
          .collection('allowed_users')
          .doc(emailKey)
          .get();

      if (!permDoc.exists) {
        throw "Access Denied: You are not added to this test batch.";
      }

      // C. Check Expiry
      DateTime expiryDate = (permDoc['expiryDate'] as Timestamp).toDate();
      if (DateTime.now().isAfter(expiryDate)) {
        throw "Access Expired: Your validity ended on ${_formatDate(expiryDate)}.";
      }

      // ✅ Go to Test
      if (context.mounted) {
        Navigator.pop(context);
        Navigator.push(
          context, 
          MaterialPageRoute(builder: (_) => AttemptTestScreen(test: test))
        );
      }

    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); 
        _showErrorDialog(context, e.toString());
      }
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(children: [Icon(Icons.lock, color: Colors.red), SizedBox(width: 10), Text("Locked")]),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))
        ],
      ),
    );
  }

  // 🔘 BUTTON BUILDER
  Widget _buildActionButton(BuildContext context, TestModel test, bool isAttempted, bool isHost, User user) {
    DateTime now = DateTime.now();
    bool isLocked = now.isBefore(test.scheduledAt);

    // 1. HOST LOGIC (Jiska host == 'yes' hai)
    if (isHost) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Manage Users Button
          IconButton(
            icon: const Icon(Icons.group_add, color: Colors.blue),
            tooltip: "Manage Allowed Users",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ManageUsersScreen(testId: test.id, testName: test.topic)),
              );
            },
          ),
          // Delete Test Button
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () async {
                bool confirm = await showDialog(
                  context: context, 
                  builder: (c) => AlertDialog(
                    title: const Text("Delete Test?"),
                    content: const Text("This cannot be undone."),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("No")),
                      TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Yes")),
                    ],
                  )
                ) ?? false;

                if(confirm) {
                   await FirebaseFirestore.instance.collection('tests').doc(test.id).delete();
                }
            },
          ),
        ],
      );
    }

    // 2. STUDENT: Already Attempted
    if (isAttempted) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
        child: const Text("View Result"),
        onPressed: () {
          Navigator.push(
            context, 
            MaterialPageRoute(
              builder: (_) => SolutionsScreen(testId: test.id, originalQuestions: test.questions)
            )
          );
        },
      );
    }

    // 3. STUDENT: Locked (Time)
    if (isLocked) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
        child: const Text("Locked"),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Test starts at ${_formatDate(test.scheduledAt)}"))
          );
        },
      );
    }

    // 4. STUDENT: Start (With Security Check)
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
      child: const Text("Start"),
      onPressed: () => _checkAccessAndStart(context, test, user),
    );
  }
}
