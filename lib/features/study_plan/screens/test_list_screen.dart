import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/test_model.dart';
import 'attempt_test_screen.dart'; // Niche defined hai
import 'solutions_screen.dart';     // Niche defined hai

class TestListScreen extends StatelessWidget {
  final bool isAdmin; 
  TestListScreen({required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: Text("Scheduled Tests")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('tests').orderBy('scheduledAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final test = TestModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
              
              // Nested Stream to check if User already attempted this test
              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .collection('my_results')
                    .doc(test.id)
                    .snapshots(),
                builder: (context, resultSnapshot) {
                  bool isAttempted = resultSnapshot.hasData && resultSnapshot.data!.exists;

                  return Card(
                    margin: EdgeInsets.all(8),
                    child: ListTile(
                      title: Text(test.subject),
                      subtitle: Text("${test.topic}\nSchedule: ${test.scheduledAt}"),
                      trailing: _buildActionButton(context, test, isAttempted, isAdmin),
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

  Widget _buildActionButton(BuildContext context, TestModel test, bool isAttempted, bool isAdmin) {
    DateTime now = DateTime.now();
    bool isLocked = now.isBefore(test.scheduledAt);

    // 1. Admin Control
    if (isAdmin) {
      return TextButton(child: Text("Edit/View"), onPressed: () {
        // Navigate to Admin Edit Screen (Not included in this snippet)
      });
    }

    // 2. User: Already Attempted
    if (isAttempted) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
        child: Text("Attempted"),
        onPressed: () {
          // Navigate to Solution Screen with test ID to fetch results
          Navigator.push(context, MaterialPageRoute(builder: (_) => 
             SolutionsScreen(testId: test.id, originalQuestions: test.questions)
          ));
        },
      );
    }

    // 3. User: Test Locked (Time nahi hua)
    if (isLocked) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        child: Text("Locked"),
        onPressed: () {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text("Please Wait"),
              content: Text("Test will start on ${test.scheduledAt}"),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text("OK"))],
            ),
          );
        },
      );
    }

    // 4. User: Ready to Start
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
      child: Text("Start Test"),
      onPressed: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => AttemptTestScreen(test: test)));
      },
    );
  }
}
