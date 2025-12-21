import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'study_results_screen.dart'; 

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
  
  // ⏱️ TIMER STATE
  Timer? _timer;
  int _remainingSeconds = 0;
  
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    questions = widget.testData['questions'] ?? [];
    marking = widget.testData['settings'] ?? {'positive': 4.0, 'negative': 1.0, 'skip': 0.0, 'duration': 60};
    
    _pageController = PageController(initialPage: 0);

    // 🕒 Initialize Timer
    int durationMinutes = marking['duration'] ?? 60;
    _remainingSeconds = durationMinutes * 60;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _timer?.cancel();
        _submitTest(autoSubmit: true); // Time Up!
      }
    });
  }

  String _formatTime(int seconds) {
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  // 🔥 Result Calculation & Save Logic
  void _submitTest({bool autoSubmit = false}) async {
    if (_isSubmitting) return;
    
    if (!autoSubmit) {
      bool confirm = await showDialog(
        context: context, 
        builder: (c) => AlertDialog(
          title: const Text("Submit Test?"),
          content: Text("You have answered ${_userAnswers.length} out of ${questions.length} questions."),
          actions: [
            TextButton(onPressed: ()=>Navigator.pop(c, false), child: const Text("Cancel")),
            TextButton(onPressed: ()=>Navigator.pop(c, true), child: const Text("Submit", style: TextStyle(fontWeight: FontWeight.bold))),
          ],
        )
      ) ?? false;

      if(!confirm) return;
    }

    setState(() => _isSubmitting = true);
    _timer?.cancel();
    
    try {
      final user = FirebaseAuth.instance.currentUser!;

      int correctCount = 0;
      int wrongCount = 0;
      int skippedCount = 0;
      double totalScore = 0;

      // 1. Calculate Score
      for (int i = 0; i < questions.length; i++) {
        int? userAns = _userAnswers[i];
        int correctAns = questions[i]['correctIndex'];

        double pos = (marking['positive'] ?? 4.0).toDouble();
        double neg = (marking['negative'] ?? 1.0).toDouble();
        // Skip mark usually 0, but creating logic just in case
        double skip = (marking['skip'] ?? 0.0).toDouble();

        if (userAns == null) {
          skippedCount++;
          totalScore += skip; // Usually 0
        } else if (userAns == correctAns) {
          correctCount++;
          totalScore += pos;
        } else {
          wrongCount++;
          totalScore -= neg; 
        }
      }

      // 2. Prepare Answer Map (Using ID as Key)
      Map<String, int> answersForDb = {};
      _userAnswers.forEach((index, optIndex) {
        String qId = questions[index]['id'] ?? "q_$index";
        answersForDb[qId] = optIndex;
      });

      // 3. Save Result
      // 🔥 CRITICAL FIX: Using .set() with TestID instead of .add()
      // This ensures TestListScreen can find the document by ID
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('test_results')
          .doc(widget.testId) // <--- Fixed here
          .set({
            'testId': widget.testId,
            'testTitle': widget.testData['testTitle'] ?? 'Test Result',
            'score': totalScore,
            'correct': correctCount,
            'wrong': wrongCount,
            'skipped': skippedCount,
            'totalQ': questions.length,
            'attemptedAt': FieldValue.serverTimestamp(),
            'questionsSnapshot': questions, 
            'userResponse': answersForDb,
            'settings': marking, // Save settings to show marks distribution later
          });

      // 4. Mark Test as Attempted (Updates global list)
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
      
      // 5. Navigate to Result Screen
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => StudyResultsScreen(
        examId: widget.examId,
        examName: widget.testData['testTitle'] ?? "Result",
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Q ${_currentQuestionIndex + 1}/${questions.length}", style: const TextStyle(fontSize: 16)),
            // ⏱️ TIMER DISPLAY
            Text("Time Left: ${_formatTime(_remainingSeconds)}", style: const TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : () => _submitTest(),
            child: const Text("SUBMIT", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: Column(
        children: [
          // 📄 1. QUESTION AREA
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: questions.length,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (index) {
                setState(() => _currentQuestionIndex = index);
              },
              itemBuilder: (context, index) {
                return _buildQuestionPage(questions[index], index);
              },
            ),
          ),

          // ↔️ 2. NAVIGATION BUTTONS
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 5)]),
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

  // 🔥 CUSTOM WIDGET FOR QUESTION PAGE
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

          // Options List
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
                  color: isSelected ? Colors.deepPurple.shade50 : Colors.white,
                  border: Border.all(
                    color: isSelected ? Colors.deepPurple : Colors.grey.shade300,
                    width: isSelected ? 2 : 1
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      height: 24, width: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? Colors.deepPurple : Colors.white,
                        border: Border.all(color: isSelected ? Colors.deepPurple : Colors.grey)
                      ),
                      child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                    ),
                    const SizedBox(width: 12),
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
