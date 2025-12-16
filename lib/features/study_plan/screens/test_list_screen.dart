import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/test_model.dart';
import 'attempt_test_screen.dart';
import 'solutions_screen.dart';
import '../../admin/screens/create_test_screen.dart'; // Admin screen import karna mat bhoolna

class TestListScreen extends StatelessWidget {
  const TestListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    // Yahan humne aapki email HARDCODE kar di hai.
    // Sirf is email wale ko hi admin features dikhenge.
    final bool isAdmin = user != null && user.email == 'opsiddh42@gmail.com';

    return Scaffold(
      appBar: AppBar(
        title: Text("Scheduled Tests"),
        actions: [
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.only(right: 18.0),
              child: Center(
                child: Text(
                  "ADMIN MODE", 
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)
                )
              ),
            )
        ],
      ),
      
      // ADMIN BUTTON: Sirf opsiddh42@gmail.com ko dikhega
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CreateTestScreen()),
                );
              },
              label: Text("Add Test"),
              icon: Icon(Icons.add),
              backgroundColor: Colors.red,
            )
          : null, // Baki users ko kuch nahi dikhega

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tests')
            .orderBy('scheduledAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) return Center(child: Text("No tests scheduled yet."));

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final test = TestModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);

              // User ka attempt status check karna
              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user!.uid)
                    .collection('my_results')
                    .doc(test.id)
                    .snapshots(),
                builder: (context, resultSnapshot) {
                  bool isAttempted = resultSnapshot.hasData && resultSnapshot.data!.exists;

                  return Card(
                    elevation: 4,
                    margin: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: ListTile(
                      leading: Icon(Icons.assignment, color: Colors.blue),
                      title: Text(test.subject, style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("${test.topic}\n${_formatDate(test.scheduledAt)}"),
                      isThreeLine: true,
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

  // Time format helper
  String _formatDate(DateTime date) {
    return "${date.day}/${date.month} - ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }

  Widget _buildActionButton(BuildContext context, TestModel test, bool isAttempted, bool isAdmin) {
    DateTime now = DateTime.now();
    bool isLocked = now.isBefore(test.scheduledAt);

    // 1. ADMIN LOGIC: Admin hamesha Edit/Delete kar sake (Future implementation)
    // Filhal Admin ko bhi 'Start' dikha rahe hain testing ke liye, ya aap 'Delete' button laga sakte ho
    if (isAdmin) {
      return IconButton(
        icon: Icon(Icons.delete, color: Colors.red),
        onPressed: () async {
            // Admin Test Delete kar sake
            await FirebaseFirestore.instance.collection('tests').doc(test.id).delete();
        },
      );
    }

    // 2. USER: Already Attempted
    if (isAttempted) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
        child: Text("View Result"),
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

    // 3. USER: Test Locked (Time nahi hua)
    if (isLocked) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
        child: Text("Locked"),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Test starts at ${_formatDate(test.scheduledAt)}"))
          );
        },
      );
    }

    // 4. USER: Ready to Start
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
      child: Text("Start"),
      onPressed: () {
        Navigator.push(
          context, 
          MaterialPageRoute(builder: (_) => AttemptTestScreen(test: test))
        );
      },
    );
  }
}
