import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class StudyResultsScreen extends StatelessWidget {
  final String examId;
  final String examName;

  const StudyResultsScreen({super.key, required this.examId, required this.examName});

  @override
  Widget build(BuildContext context) {
    String userId = FirebaseAuth.instance.currentUser?.uid ?? "";

    return Scaffold(
      appBar: AppBar(title: Text("$examName Report Card 📊")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('user_exam_results') // ⚡ Yahan Results save honge
            .where('userId', isEqualTo: userId)
            .where('examId', isEqualTo: examId)
            .orderBy('completedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          if (snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.analytics_outlined, size: 60, color: Colors.grey),
                  const SizedBox(height: 10),
                  Text("No tests attempted yet for $examName", style: const TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var data = snapshot.data!.docs[index];
              
              // Calculation
              int score = data['score'];
              int total = data['totalQuestions'];
              double percentage = (score / total) * 100;
              Color gradeColor = percentage >= 60 ? Colors.green : (percentage >= 33 ? Colors.orange : Colors.red);

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: gradeColor.withOpacity(0.1),
                    child: Text("${percentage.toInt()}%", style: TextStyle(color: gradeColor, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  title: Text(data['weekTitle'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Date: ${DateFormat('dd MMM, hh:mm a').format((data['completedAt'] as Timestamp).toDate())}"),
                  trailing: Text("$score / $total", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
