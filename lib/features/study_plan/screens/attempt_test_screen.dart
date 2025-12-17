import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  
  // 🔥 Controller for Swiping
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    questions = widget.testData['questions'];
    marking = widget.testData['settings'];
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // 🔥 Result Calculation Logic
  void _submitTest() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    
    try {
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
          totalScore -= (marking['negative'] ?? 1); 
        }
      }

      // 1️⃣ Save Result in User's Collection
      await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('test_results').add({
        'testId': widget.testId,
        'testTitle': widget.testData['testTitle'],
        'score': totalScore,
        'correct': correctCount,
        'wrong': wrongCount,
        'skipped': skippedCount,
        'totalQ': questions.length,
        'attemptedAt': FieldValue.serverTimestamp(),
        // Saving details for solution view
        'questionsSnapshot': questions,
        'userResponse': _userAnswers.map((k, v) => MapEntry(questions[k]['id'] ?? questions[k]['question'], v)),
      });

      // 2️⃣ Mark Test as Attempted
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
        examName: widget.testData['testTitle'],
      )));
      
    } catch (e) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
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
      body: Column(
        children: [
          // 🔥 1. SWIPEABLE QUESTION AREA
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: questions.length,
              onPageChanged: (index) {
                setState(() => _currentQuestionIndex = index);
              },
              itemBuilder: (context, index) {
                return _buildQuestionPage(questions[index], index);
              },
            ),
          ),

          // 🔥 2. NAVIGATION BUTTONS
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: _currentQuestionIndex == 0 
                    ? null 
                    : () {
                        _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                      },
                  child: const Text("Previous"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                  onPressed: _currentQuestionIndex == questions.length - 1 
                      ? null 
                      : () {
                          _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                        },
                  child: const Text("Next"),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // 🔥 CUSTOM WIDGET FOR QUESTION & OPTIONS
  Widget _buildQuestionPage(Map<String, dynamic> q, int qIndex) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question Text
          Text(
            q['question'], 
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
          ),
          const SizedBox(height: 20),

          // 🔥 CUSTOM CLICKABLE OPTIONS
          ...List.generate(q['options'].length, (optIndex) {
            bool isSelected = _userAnswers[qIndex] == optIndex;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _userAnswers[qIndex] = optIndex;
                });
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  // 🎨 Change Color on Selection
                  color: isSelected ? Colors.deepPurple.shade50 : Colors.white,
                  border: Border.all(
                    color: isSelected ? Colors.deepPurple : Colors.grey.shade300,
                    width: isSelected ? 2 : 1
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    // Custom Radio Circle
                    Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: isSelected ? Colors.deepPurple : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    
                    // Option Text
                    Expanded(
                      child: Text(
                        q['options'][optIndex],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.deepPurple.shade900 : Colors.black87
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
