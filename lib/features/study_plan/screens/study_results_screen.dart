import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// ✅ IMPORT THE NEW SOLUTION SCREEN
import 'package:exambeing/features/study_plan/screens/solutions_screen.dart'; 

class StudyResultsScreen extends StatelessWidget {
  final String examId;
  final String examName;

  const StudyResultsScreen({super.key, required this.examId, required this.examName});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("My Performance 🏆"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('test_results')
            .orderBy('attemptedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("No tests attempted yet!"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              double score = (data['score'] as num).toDouble();
              
              // Formatting Date
              Timestamp? ts = data['attemptedAt'];
              String dateStr = ts != null 
                ? DateFormat('dd MMM, hh:mm a').format(ts.toDate()) 
                : "Just now";

              return Card(
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data['testTitle'] ?? "Test", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(dateStr, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: score >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(20)
                            ),
                            child: Text(
                              "Score: ${score.toStringAsFixed(1)}", 
                              style: TextStyle(fontWeight: FontWeight.bold, color: score >= 0 ? Colors.green : Colors.red)
                            ),
                          )
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(Icons.check_circle, "${data['correct']}", Colors.green, "Correct"),
                          _buildStatItem(Icons.cancel, "${data['wrong']}", Colors.red, "Wrong"),
                          _buildStatItem(Icons.remove_circle_outline, "${data['skipped']}", Colors.orange, "Skipped"),
                        ],
                      ),
                      const SizedBox(height: 15),
                      
                      // 👇 UPDATED BUTTON LOGIC HERE
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                             // Check if detailed data exists (Old results might not have it)
                             if (data['questionsSnapshot'] != null && data['userResponse'] != null) {
                               Navigator.push(
                                 context, 
                                 MaterialPageRoute(builder: (c) => TestSolutionScreen(
                                   testTitle: data['testTitle'] ?? "Solutions",
                                   questions: data['questionsSnapshot'],
                                   userAnswers: data['userResponse']
                                 ))
                               );
                             } else {
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Details not available for this old test.")));
                             }
                          },
                          child: const Text("View Solutions & Analysis"),
                        ),
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String val, Color color, String label) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}
