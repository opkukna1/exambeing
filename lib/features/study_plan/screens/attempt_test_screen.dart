import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// 🔥 Ensure this import is correct based on your project structure
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
  
  // 🔥 Controller for Swiping
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    questions = widget.testData['questions'] ?? [];
    // Handle settings safely (Default: +4, -1)
    marking = widget.testData['settings'] ?? {'positive': 4.0, 'negative': 1.0, 'skip': 0.0};
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // 🔥 Result Calculation & Save Logic
  void _submitTest() async {
    if (_isSubmitting) return;
    
    // Confirm Dialog
    bool confirm = await showDialog(
      context: context, 
      builder: (c) => AlertDialog(
        title: const Text("Submit Test?"),
        content: const Text("Are you sure you want to finish?"),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(c, false), child: const Text("Cancel")),
          TextButton(onPressed: ()=>Navigator.pop(c, true), child: const Text("Submit")),
        ],
      )
    ) ?? false;

    if(!confirm) return;

    setState(() => _isSubmitting = true);
    
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
        double skip = (marking['skip'] ?? 0.0).toDouble();

        if (userAns == null) {
          skippedCount++;
          totalScore += skip;
        } else if (userAns == correctAns) {
          correctCount++;
          totalScore += pos;
        } else {
          wrongCount++;
          totalScore -= neg; 
        }
      }

      // 2. Prepare Answer Map for Database (Use Question ID as Key)
      Map<String, int> answersForDb = {};
      _userAnswers.forEach((index, optIndex) {
        // Fallback: If ID is missing, use Question Text as ID (Older tests compatibility)
        String qId = questions[index]['id'] ?? questions[index]['question'];
        answersForDb[qId] = optIndex;
      });

      // 3. Save Result in User's Collection
      // Note: We use .add() so a user can have multiple attempts history if needed later
      await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('test_results').add({
        'testId': widget.testId,
        'testTitle': widget.testData['testTitle'] ?? 'Test Result',
        'score': totalScore,
        'correct': correctCount,
        'wrong': wrongCount,
        'skipped': skippedCount,
        'totalQ': questions.length,
        'attemptedAt': FieldValue.serverTimestamp(),
        // Saving full snapshot so solution works even if teacher deletes original test
        'questionsSnapshot': questions, 
        'userResponse': answersForDb,
      });

      // 4. Mark Test as Attempted (Updates the main test document)
      // This allows the "Start" button to change to "Result"
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
      
      // 5. Navigate to Result Screen (Replace stack so user can't go back)
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
                    Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: isSelected ? Colors.deepPurple : Colors.grey,
                      size: 20,
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
