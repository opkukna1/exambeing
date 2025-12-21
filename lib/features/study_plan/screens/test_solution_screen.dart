import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TestSolutionScreen extends StatefulWidget {
  final String testId;
  final List<dynamic> originalQuestions;

  const TestSolutionScreen({
    super.key, 
    required this.testId, 
    required this.originalQuestions
  });

  @override
  State<TestSolutionScreen> createState() => _TestSolutionScreenState();
}

class _TestSolutionScreenState extends State<TestSolutionScreen> {
  Map<String, dynamic>? resultData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchResult();
  }

  // 🔥 Fetch User Result from Firestore
  Future<void> _fetchResult() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      QuerySnapshot query = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('test_results')
          .where('testId', isEqualTo: widget.testId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        if(mounted) {
          setState(() {
            resultData = query.docs.first.data() as Map<String, dynamic>;
            isLoading = false;
          });
        }
      } else {
        if(mounted) setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching result: $e");
      if(mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    if (resultData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Result")),
        body: const Center(child: Text("No result found. Please attempt the test first.")),
      );
    }

    // ✅ Setup Data
    Map<String, dynamic> userResponses = resultData!['userResponse'] ?? {};
    int correct = resultData!['correct'] ?? 0;
    int wrong = resultData!['wrong'] ?? 0;
    int skipped = resultData!['skipped'] ?? 0;
    double score = (resultData!['score'] ?? 0).toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Solutions & Analysis 🧐"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Column(
        children: [
          // 📊 1. SCORE HEADER
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.deepPurple.shade50,
            child: Column(
              children: [
                Text("Total Score: ${score.toStringAsFixed(1)}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatBadge("Correct", correct, Colors.green),
                    _buildStatBadge("Wrong", wrong, Colors.red),
                    _buildStatBadge("Skipped", skipped, Colors.orange),
                  ],
                )
              ],
            ),
          ),
          
          // 📝 2. QUESTION LIST
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.originalQuestions.length,
              itemBuilder: (context, index) {
                var q = widget.originalQuestions[index];
                
                // ID Mapping (Fallback to question text if ID missing)
                String qKey = q['id'] ?? q['question']; 
                
                int? userSelectedOpt = userResponses[qKey];
                int correctOpt = q['correctIndex'];

                // Status Logic
                bool isSkipped = userSelectedOpt == null;
                bool isCorrect = userSelectedOpt == correctOpt;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSkipped ? Colors.orange.shade200 
                           : isCorrect ? Colors.green.shade200 
                           : Colors.red.shade200,
                      width: 1.5
                    )
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: Q.No & Status
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Q.${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSkipped ? Colors.orange.shade50 : isCorrect ? Colors.green.shade50 : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(4)
                              ),
                              child: Text(
                                isSkipped ? "SKIPPED" : isCorrect ? "CORRECT" : "WRONG",
                                style: TextStyle(
                                  fontSize: 10, 
                                  fontWeight: FontWeight.bold,
                                  color: isSkipped ? Colors.orange : isCorrect ? Colors.green : Colors.red
                                ),
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 10),
                        
                        // Question Text
                        Text(
                          q['question'], 
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                        ),
                        const SizedBox(height: 15),

                        // Options Loop
                        ...List.generate(q['options'].length, (optIndex) {
                          String optionText = q['options'][optIndex];
                          
                          Color bgColor = Colors.white;
                          Color textColor = Colors.black87;
                          IconData? icon;

                          if (optIndex == correctOpt) {
                            // ✅ Correct Answer (Always Green)
                            bgColor = Colors.green.shade50;
                            textColor = Colors.green.shade900;
                            icon = Icons.check_circle;
                          } else if (optIndex == userSelectedOpt) {
                            // ❌ User's Wrong Answer (Red)
                            bgColor = Colors.red.shade50;
                            textColor = Colors.red.shade900;
                            icon = Icons.cancel;
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200)
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    "${String.fromCharCode(65 + optIndex)}. $optionText",
                                    style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
                                  ),
                                ),
                                if (icon != null) Icon(icon, size: 18, color: textColor)
                              ],
                            ),
                          );
                        }),

                        // 💡 EXPLANATION SECTION
                        if (q['explanation'] != null && q['explanation'].toString().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Divider(),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade100)
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.lightbulb, size: 16, color: Colors.blue),
                                    SizedBox(width: 5),
                                    Text("Explanation", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  q['explanation'],
                                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                                ),
                              ],
                            ),
                          )
                        ]
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Helper for Top Stats
  Widget _buildStatBadge(String label, int count, Color color) {
    return Column(
      children: [
        CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Text("$count", style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12))
      ],
    );
  }
}
