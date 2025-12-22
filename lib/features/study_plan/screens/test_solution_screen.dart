import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TestSolutionScreen extends StatefulWidget {
  final String testId;
  // Hum Map receive karenge taaki crash na ho
  final List<Map<String, dynamic>> originalQuestions; 
  final String? examName;

  const TestSolutionScreen({
    super.key, 
    required this.testId, 
    required this.originalQuestions,
    this.examName
  });

  @override
  State<TestSolutionScreen> createState() => _TestSolutionScreenState();
}

class _TestSolutionScreenState extends State<TestSolutionScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _userResultData = {};
  Map<String, dynamic> _userResponses = {}; // Key: QuestionID, Value: SelectedOptionIndex

  @override
  void initState() {
    super.initState();
    _fetchUserResult();
  }

  Future<void> _fetchUserResult() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('test_results')
          .doc(widget.testId)
          .get();

      if (doc.exists) {
        setState(() {
          _userResultData = doc.data() as Map<String, dynamic>;
          // User ke answers map ko load karo
          _userResponses = Map<String, dynamic>.from(_userResultData['userResponse'] ?? {});
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching result: $e");
      setState(() => _isLoading = false);
    }
  }

  // Helper to ensure Options are List<String>
  List<String> _getOptions(Map<String, dynamic> q) {
    if (q['options'] != null && (q['options'] as List).isNotEmpty) {
      return List<String>.from(q['options']);
    }
    // Fallback for old data
    List<String> opts = [];
    for (int i = 0; i < 6; i++) {
      if (q.containsKey('option$i')) opts.add(q['option$i'].toString());
    }
    return opts;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    // Stats for Header
    int correct = _userResultData['correct'] ?? 0;
    int wrong = _userResultData['wrong'] ?? 0;
    int skipped = _userResultData['skipped'] ?? 0;
    double score = (_userResultData['score'] ?? 0).toDouble();

    return Scaffold(
      appBar: AppBar(title: Text(widget.examName ?? "Analysis")),
      body: Column(
        children: [
          // 📊 1. SCORE HEADER (Jo aapke screenshot mein hai)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.deepPurple.shade50),
            child: Column(
              children: [
                Text("Total Score: ${score.toStringAsFixed(1)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                const SizedBox(height: 15),
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
              padding: const EdgeInsets.all(12),
              itemCount: widget.originalQuestions.length,
              itemBuilder: (context, index) {
                var qData = widget.originalQuestions[index];
                return _buildSolutionCard(qData, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String label, int count, Color color) {
    return Column(
      children: [
        CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Text("$count", style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(fontSize: 12))
      ],
    );
  }

  Widget _buildSolutionCard(Map<String, dynamic> q, int index) {
    // 1. Prepare Data
    String qId = q['id'] ?? "q_$index";
    String questionText = q['question'] ?? q['questionText'] ?? 'No Question';
    List<String> options = _getOptions(q);
    int correctIndex = q['correctIndex'] ?? q['correctAnswerIndex'] ?? 0;
    String explanation = q['explanation'] ?? q['solution'] ?? '';

    // 2. Determine User Status
    // Firestore mein key String ho sakti hai, UI list int hai
    int? userSelectedIndex;
    if (_userResponses.containsKey(qId)) {
      userSelectedIndex = _userResponses[qId];
    }

    bool isSkipped = userSelectedIndex == null;
    bool isCorrect = userSelectedIndex == correctIndex;

    // Card Color Border
    Color statusColor = isSkipped ? Colors.orange : (isCorrect ? Colors.green : Colors.red);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: statusColor.withOpacity(0.5))),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question Label with Status Icon
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Q${index + 1}.", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(child: Text(questionText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
                Icon(
                  isSkipped ? Icons.warning_amber : (isCorrect ? Icons.check_circle : Icons.cancel),
                  color: statusColor,
                )
              ],
            ),
            const SizedBox(height: 15),

            // Options List
            ...List.generate(options.length, (optIndex) {
              bool isThisCorrect = (optIndex == correctIndex);
              bool isThisUserSelected = (optIndex == userSelectedIndex);
              
              Color optColor = Colors.white;
              Color borderColor = Colors.grey.shade300;
              IconData? icon;

              // Logic for coloring options
              if (isThisCorrect) {
                optColor = Colors.green.shade50;
                borderColor = Colors.green;
                icon = Icons.check_circle;
              } else if (isThisUserSelected) {
                // Agar user ne ye select kiya aur ye galat hai (kyunki sahi wala upar cover ho gaya)
                optColor = Colors.red.shade50;
                borderColor = Colors.red;
                icon = Icons.cancel;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: optColor,
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    if (icon != null) Icon(icon, size: 18, color: borderColor) else const SizedBox(width: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(options[optIndex], style: TextStyle(color: Colors.black87, fontWeight: isThisCorrect || isThisUserSelected ? FontWeight.bold : FontWeight.normal))),
                  ],
                ),
              );
            }),

            // Explanation Section
            if (explanation.isNotEmpty) ...[
              const Divider(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("💡 Explanation:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                    const SizedBox(height: 5),
                    Text(explanation, style: const TextStyle(fontSize: 14)),
                  ],
                ),
              )
            ]
          ],
        ),
      ),
    );
  }
}
