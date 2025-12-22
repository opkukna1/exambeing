import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 🔥 REQUIRED
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
  Map<int, int> _userAnswers = {}; 
  int _currentQuestionIndex = 0;
  bool _isSubmitting = false;

  late List<dynamic> questions;
  late Map<String, dynamic> marking;
  
  Timer? _timer;
  int _remainingSeconds = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    
    // 🔥 FORCE FULL SCREEN (Immersive Mode)
    // Ye status bar aur navigation bar dono ko hide karega
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    questions = widget.testData['questions'] ?? [];
    marking = widget.testData['settings'] ?? {'positive': 4.0, 'negative': 1.0, 'skip': 0.0, 'duration': 60};
    
    _pageController = PageController(initialPage: 0);

    int durationMinutes = marking['duration'] ?? 60;
    _remainingSeconds = durationMinutes * 60;
    _startTimer();
  }

  @override
  void dispose() {
    // 🔥 RESTORE NORMAL UI (Show status bar again)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _timer?.cancel();
        _submitTest(autoSubmit: true); 
      }
    });
  }

  String _formatTime(int seconds) {
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> _normalizeQuestion(dynamic q) {
    if (q is Map<String, dynamic> || q is Map) {
      return Map<String, dynamic>.from(q as Map);
    } else {
      try { return q.toMap(); } catch (e) {
        return { 'id': q.id, 'question': q.questionText, 'options': q.options, 'correctIndex': q.correctIndex, 'explanation': q.explanation };
      }
    }
  }

  void _submitTest({bool autoSubmit = false}) async {
    if (_isSubmitting) return;
    
    if (!autoSubmit) {
      bool confirm = await showDialog(context: context, builder: (c) => AlertDialog(
          title: const Text("Submit Test?"),
          content: Text("You answered ${_userAnswers.length}/${questions.length} questions."),
          actions: [TextButton(onPressed: ()=>Navigator.pop(c, false), child: const Text("Cancel")), TextButton(onPressed: ()=>Navigator.pop(c, true), child: const Text("Submit"))]
        )) ?? false;
      if(!confirm) return;
    }

    setState(() => _isSubmitting = true);
    _timer?.cancel();
    
    try {
      final user = FirebaseAuth.instance.currentUser!;
      int correctCount = 0; int wrongCount = 0; int skippedCount = 0; double totalScore = 0;
      List<Map<String, dynamic>> finalQuestionsData = [];

      for (int i = 0; i < questions.length; i++) {
        var qData = _normalizeQuestion(questions[i]);
        finalQuestionsData.add(qData);
        int? userAns = _userAnswers[i];
        int correctAns = qData['correctIndex'] ?? qData['correctAnswerIndex'] ?? 0;
        double pos = (marking['positive'] ?? 4.0).toDouble();
        double neg = (marking['negative'] ?? 1.0).toDouble();

        if (userAns == null) { skippedCount++; } 
        else if (userAns == correctAns) { correctCount++; totalScore += pos; } 
        else { wrongCount++; totalScore -= neg; }
      }

      Map<String, int> answersForDb = {};
      _userAnswers.forEach((index, optIndex) {
         var qData = _normalizeQuestion(questions[index]);
         String qId = qData['id'] ?? "q_$index";
         answersForDb[qId] = optIndex;
      });

      await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('test_results').doc(widget.testId).set({
            'testId': widget.testId, 'testTitle': widget.testData['testTitle'] ?? 'Test Result', 'score': totalScore,
            'correct': correctCount, 'wrong': wrongCount, 'skipped': skippedCount, 'totalQ': questions.length,
            'attemptedAt': FieldValue.serverTimestamp(), 'questionsSnapshot': finalQuestionsData, 'userResponse': answersForDb, 'settings': marking,
          });

      await FirebaseFirestore.instance.collection('study_schedules').doc(widget.examId).collection('weeks').doc(widget.weekId).collection('tests').doc(widget.testId).update({
        'attemptedUsers': FieldValue.arrayUnion([user.uid])
      });

      if (!mounted) return;
      // Restore UI before leaving
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

      Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => StudyResultsScreen(examId: widget.examId, examName: widget.testData['testTitle'] ?? "Result")));
      
    } catch (e) {
      setState(() => _isSubmitting = false);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, 
      child: Scaffold(
        // AppBar with no back button
        appBar: AppBar(
          automaticallyImplyLeading: false, 
          elevation: 1,
          backgroundColor: Colors.white,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Q ${_currentQuestionIndex + 1}/${questions.length}", style: const TextStyle(fontSize: 16, color: Colors.black)),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(20)), child: Text("⏳ ${_formatTime(_remainingSeconds)}", style: const TextStyle(fontSize: 14, color: Colors.red, fontWeight: FontWeight.bold))),
            ],
          ),
          actions: [TextButton(onPressed: _isSubmitting ? null : () => _submitTest(), child: const Text("SUBMIT", style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)))],
        ),
        body: Column(
          children: [
            Expanded(child: PageView.builder(controller: _pageController, itemCount: questions.length, physics: const BouncingScrollPhysics(), onPageChanged: (index) => setState(() => _currentQuestionIndex = index), itemBuilder: (context, index) => _buildQuestionPage(_normalizeQuestion(questions[index]), index))),
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 5)]), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  ElevatedButton(onPressed: _currentQuestionIndex == 0 ? null : () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut), child: const Text("Previous")),
                  ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white), onPressed: _currentQuestionIndex == questions.length - 1 ? null : () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut), child: const Text("Next")),
                ]))
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionPage(Map<String, dynamic> q, int qIndex) {
    List<dynamic> options = [];
    if (q['options'] != null && (q['options'] as List).isNotEmpty) { options = q['options']; } 
    else { for(int i=0; i<6; i++) { if(q.containsKey('option$i')) options.add(q['option$i']); } }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(q['question'] ?? q['questionText'] ?? 'Loading...', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.4)),
          const SizedBox(height: 25),
          ...List.generate(options.length, (optIndex) {
            bool isSelected = _userAnswers[qIndex] == optIndex;
            return GestureDetector(onTap: () => setState(() => _userAnswers[qIndex] = optIndex), child: Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), decoration: BoxDecoration(color: isSelected ? Colors.deepPurple.shade50 : Colors.white, border: Border.all(color: isSelected ? Colors.deepPurple : Colors.grey.shade300, width: isSelected ? 2 : 1), borderRadius: BorderRadius.circular(12)), child: Row(children: [
                    Container(height: 24, width: 24, decoration: BoxDecoration(shape: BoxShape.circle, color: isSelected ? Colors.deepPurple : Colors.white, border: Border.all(color: isSelected ? Colors.deepPurple : Colors.grey.shade400)), child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null),
                    const SizedBox(width: 15),
                    Expanded(child: Text(options[optIndex].toString(), style: TextStyle(fontSize: 16, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.deepPurple.shade900 : Colors.black87))),
                  ])));
          }),
        ],
      ),
    );
  }
}
