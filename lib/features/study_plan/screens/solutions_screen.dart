import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/test_model.dart';

class SolutionsScreen extends StatelessWidget {
  final String testId;
  final List<Question> originalQuestions;

  const SolutionsScreen({required this.testId, required this.originalQuestions});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: Text("Result & Solutions")),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(userId).collection('my_results').doc(testId).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final userAnswers = data['userAnswers'] as Map<String, dynamic>; // { "qId": "A" }
          final score = data['score'];

          return Column(
            children: [
              Container(
                padding: EdgeInsets.all(20),
                color: Colors.blueAccent.withOpacity(0.1),
                child: Center(child: Text("Your Score: $score / ${originalQuestions.length}", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: originalQuestions.length,
                  itemBuilder: (context, index) {
                    final question = originalQuestions[index];
                    final userAnswer = userAnswers[question.id] ?? "Skipped";
                    final isCorrect = userAnswer == question.correctOption;

                    return Card(
                      color: isCorrect ? Colors.green[50] : Colors.red[50],
                      margin: EdgeInsets.all(8),
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Q${index+1}: ${question.questionText}", style: TextStyle(fontWeight: FontWeight.bold)),
                            SizedBox(height: 5),
                            Text("Your Answer: $userAnswer", style: TextStyle(color: isCorrect ? Colors.green : Colors.red)),
                            if (!isCorrect) 
                              Text("Correct Answer: ${question.correctOption}", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            Divider(),
                            Text("Explanation: ", style: TextStyle(fontWeight: FontWeight.w600)),
                            Text(question.explanation),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
