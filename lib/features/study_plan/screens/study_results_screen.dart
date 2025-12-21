import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// ✅ IMPORT THE NEW SOLUTION SCREEN
import 'package:exambeing/features/study_plan/screens/test_solution_screen.dart'; 

class StudyResultsScreen extends StatelessWidget {
  final String examId;
  final String examName;

  const StudyResultsScreen({super.key, required this.examId, required this.examName});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text("Please Login")));

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
            .doc(user.uid)
            .collection('test_results')
            .orderBy('attemptedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.analytics_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 10),
                  const Text("No tests attempted yet!", style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 5),
                  const Text("Complete a test to see analytics.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            );
          }

          // 📊 Calculate Overall Stats
          double totalScore = 0;
          int totalTests = docs.length;
          for (var doc in docs) {
            totalScore += (doc['score'] as num).toDouble();
          }
          double avgScore = totalTests > 0 ? totalScore / totalTests : 0;

          return Column(
            children: [
              // 📈 SUMMARY CARD
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade700]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.deepPurple.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildHeaderStat("Total Tests", "$totalTests", Icons.assignment_turned_in),
                    Container(width: 1, height: 40, color: Colors.white30),
                    _buildHeaderStat("Avg. Score", avgScore.toStringAsFixed(1), Icons.bar_chart),
                  ],
                ),
              ),

              // 📝 LIST OF RESULTS
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    double score = (data['score'] as num).toDouble();
                    int totalQ = data['totalQ'] ?? 0;
                    
                    // Formatting Date
                    Timestamp? ts = data['attemptedAt'];
                    String dateStr = ts != null 
                      ? DateFormat('dd MMM, hh:mm a').format(ts.toDate()) 
                      : "Just now";

                    return Card(
                      margin: const EdgeInsets.only(bottom: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(data['testTitle'] ?? "Test", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      const SizedBox(height: 4),
                                      Text(dateStr, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                    ],
                                  ),
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
                                _buildStatItem(Icons.help_outline, "${data['skipped']}", Colors.orange, "Skipped"),
                              ],
                            ),
                            const SizedBox(height: 15),
                            
                            // 👇 ACTION BUTTON
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.visibility, size: 16),
                                label: const Text("View Solutions & Analysis"),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.deepPurple,
                                  side: const BorderSide(color: Colors.deepPurple),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                                ),
                                onPressed: () {
                                   if (data['questionsSnapshot'] != null) {
                                     // Ensure we are passing List<dynamic> correctly
                                     List<dynamic> qList = data['questionsSnapshot'] as List<dynamic>;
                                     
                                     Navigator.push(
                                       context, 
                                       MaterialPageRoute(builder: (c) => TestSolutionScreen(
                                         testId: data['testId'] ?? docs[index].id, 
                                         originalQuestions: qList
                                       ))
                                     );
                                   } else {
                                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Analysis not available for this test.")));
                                   }
                                },
                              ),
                            )
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

  Widget _buildHeaderStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String val, Color color, String label) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}
