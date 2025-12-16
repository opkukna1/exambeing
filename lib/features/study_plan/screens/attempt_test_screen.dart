import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// ✅ Import Result Screen
import 'package:exambeing/features/study_plan/screens/study_results_screen.dart';

class AttemptTestScreen extends StatefulWidget {
  final String testId;
  final Map<String, dynamic> testData;
  final String examId;
  final String weekId;

  const AttemptTestScreen({
    super.key, 
    required this.testId, 
    required this.testData,
    required this.examId,
    required this.weekId,
  });

  @override
  State<AttemptTestScreen> createState() => _AttemptTestScreenState();
}

class _AttemptTestScreenState extends State<AttemptTestScreen> {
  Map<int, int> _userAnswers = {}; // Index: OptionIndex
  int _currentQuestionIndex = 0;
  bool _isSubmitting = false;

  late List<dynamic> questions;
  late Map<String, dynamic> marking;

  @override
  void initState() {
    super.initState();
    questions = widget.testData['questions'];
    marking = widget.testData['settings'];
  }

  // 🔥 Result Calculation Logic
  void _submitTest() async {
    setState(() => _isSubmitting = true);
    final user = FirebaseAuth.instance.currentUser!;

    int correctCount = 0;
    int wrongCount = 0;
    int skippedCount = 0;
    double totalScore = 0;

    for (int i = 0; i < questions.length; i++) {
      int? userAns = _userAnswers[i];
      int correctAns = questions[i]['correctIndex'];

      if (userAns == null) {
        skippedCount++;
        totalScore += (marking['skip'] ?? 0);
      } else if (userAns == correctAns) {
        correctCount++;
        totalScore += (marking['positive'] ?? 4);
      } else {
        wrongCount++;
        totalScore -= (marking['negative'] ?? 1); // Subtracting negative marks
      }
    }

    double percentage = (correctCount / questions.length) * 100;

    // 1️⃣ Save Result in User's Collection
    await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('test_results').add({
      'testTitle': widget.testData['testTitle'],
      'score': totalScore,
      'correct': correctCount,
      'wrong': wrongCount,
      'skipped': skippedCount,
      'totalQ': questions.length,
      'attemptedAt': FieldValue.serverTimestamp(),
    });

    // 2️⃣ Mark Test as Attempted in Global Schedule (Prevent Re-attempt)
    await FirebaseFirestore.instance
        .collection('study_schedules')
        .doc(widget.examId)
        .collection('weeks')
        .doc(widget.weekId)
        .collection('tests')
        .doc(widget.testId)
        .update({
      'attemptedUsers': FieldValue.arrayUnion([user.uid])
    });

    if (!mounted) return;
    
    // 3️⃣ Go to Result Screen
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => StudyResultsScreen(
      examId: widget.examId,
      examName: widget.testData['testTitle'], // Or pass specific result data
    )));
    
    // Optional: Show immediate popup
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Test Submitted! Score: $totalScore")));
  }

  @override
  Widget build(BuildContext context) {
    var q = questions[_currentQuestionIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text("Q ${_currentQuestionIndex + 1}/${questions.length}"),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submitTest,
            child: const Text("SUBMIT", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question Text
            Text(q['question'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // Options
            ...List.generate(4, (index) {
              return RadioListTile<int>(
                value: index,
                groupValue: _userAnswers[_currentQuestionIndex],
                title: Text(q['options'][index]),
                onChanged: (val) {
                  setState(() {
                    _userAnswers[_currentQuestionIndex] = val!;
                  });
                },
              );
            }),

            const Spacer(),

            // Navigation Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: _currentQuestionIndex == 0 ? null : () => setState(() => _currentQuestionIndex--),
                  child: const Text("Previous"),
                ),
                ElevatedButton(
                  onPressed: _currentQuestionIndex == questions.length - 1 
                      ? null 
                      : () => setState(() => _currentQuestionIndex++),
                  child: const Text("Next"),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
