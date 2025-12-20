import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 🔥 Needed for Saving
import 'package:exambeing/models/question_model.dart';
import 'package:exambeing/services/revision_db.dart';
import 'package:exambeing/services/ad_manager.dart';
import 'admin_edit_dialog.dart'; // ✅ Correct Import

class PracticeMcqScreen extends StatefulWidget {
  final Map<String, dynamic> quizData;
  const PracticeMcqScreen({super.key, required this.quizData});

  @override
  State<PracticeMcqScreen> createState() => _PracticeMcqScreenState();
}

class _PracticeMcqScreenState extends State<PracticeMcqScreen> {
  late final List<Question> questions;
  late final String topicName;
  late final String mode;
  
  bool isRevision = false;
  List<String> dbIds = [];

  // ✅ ADMIN VARIABLES
  bool _canEdit = false;
  final String _adminEmail = "opsiddh42@gmail.com"; 

  final PageController _pageController = PageController();
  final Map<int, String> _selectedAnswers = {};
  int _currentPage = 0;
  bool _isSubmitted = false;
  
  Timer? _timer;
  int _start = 0;
  String _timerText = "00:00";
  late DateTime _quizStartTime;

  @override
  void initState() {
    super.initState();
    questions = widget.quizData['questions'] as List<Question>;
    topicName = widget.quizData['topicName'] as String;
    mode = widget.quizData['mode'] as String;
    
    if (widget.quizData.containsKey('isRevision')) {
      isRevision = widget.quizData['isRevision'] as bool;
      dbIds = widget.quizData['dbIds'] as List<String>;
    }

    _quizStartTime = DateTime.now();
    _checkAdmin();

    if (mode == 'test') {
      _start = questions.length * 60; 
      startTimer();
    }
  }

  void _checkAdmin() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email == _adminEmail) {
      setState(() {
        _canEdit = true;
      });
    }
  }

  void startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_start <= 0) {
        timer.cancel();
        if (!_isSubmitted) _submitQuiz();
      } else {
        setState(() {
          _start--;
          int minutes = _start ~/ 60;
          int seconds = _start % 60;
          _timerText = "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
        });
      }
    });
  }

  // 🔥 1. NEW SMART SAVING FUNCTION FOR AI (Logs Array)
  Future<void> _saveTestResultsForAi({
    required int score,
    required int correctCount,
    required int totalQuestions,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // A. Prepare Logs List (One Array for all questions)
      List<Map<String, dynamic>> questionLogs = [];

      for (int i = 0; i < questions.length; i++) {
        final q = questions[i];
        
        // Find user answer
        String uAns = _selectedAnswers[i] ?? "Skipped";
        
        // Find correct answer text
        String cAns = "";
        if (q.correctAnswerIndex >= 0 && q.correctAnswerIndex < q.options.length) {
          cAns = q.options[q.correctAnswerIndex];
        }

        // Check if correct
        bool isCorrect = (uAns == cAns);

        // Add to log
        questionLogs.add({
          'q': q.questionText, // Question
          'u': uAns,           // User Answer
          'c': cAns,           // Correct Answer
          's': isCorrect,      // Status
          't': topicName,      // Topic Name (Optional inside array)
        });
      }

      // B. Save to Firestore (Single Write)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('test_results')
          .add({
        'topicName': topicName,
        'score': score, // Raw Score (Correct Count)
        'totalQuestions': totalQuestions,
        'timestamp': FieldValue.serverTimestamp(),
        'logs': questionLogs, // 🔥 This Array is crucial for AI
      });

      debugPrint("✅ AI Logs Saved Successfully!");

    } catch (e) {
      debugPrint("❌ Error Saving AI Logs: $e");
    }
  }
  
  Future<void> _submitQuiz() async {
    if (_isSubmitted) return;
    setState(() => _isSubmitted = true);
    _timer?.cancel();
    
    final DateTime endTime = DateTime.now();
    final Duration timeTaken = endTime.difference(_quizStartTime);

    double finalScore = 0.0;
    int correctCount = 0;
    int wrongCount = 0;
    int unattemptedCount = 0;

    for (int i = 0; i < questions.length; i++) {
      if (_selectedAnswers.containsKey(i)) {
        String correctAnswer = "";
        if (questions[i].correctAnswerIndex >= 0 && questions[i].correctAnswerIndex < questions[i].options.length) {
            correctAnswer = questions[i].options[questions[i].correctAnswerIndex];
        }

        if (_selectedAnswers[i] == correctAnswer) {
          finalScore += 1.0;
          correctCount++;

          if (isRevision && i < dbIds.length) {
            await RevisionDB.instance.incrementAttempt(dbIds[i]);
          }

        } else {
          finalScore -= 0.33;
          wrongCount++;
        }
      } else {
        unattemptedCount++;
      }
    }

    if (finalScore < 0) finalScore = 0;

    // 🔥 2. CALL SAVING FUNCTION HERE (Background mein save hoga)
    _saveTestResultsForAi(
      score: correctCount,
      correctCount: correctCount,
      totalQuestions: questions.length,
    );

    if (mounted) {
      AdManager.showInterstitialAd(() {
        if (mounted) {
          context.replace( 
            '/score-screen',
            extra: {
              'totalQuestions': questions.length,
              'finalScore': finalScore,
              'correctCount': correctCount,
              'wrongCount': wrongCount,
              'unattemptedCount': unattemptedCount,
              'topicName': topicName,
              'questions': questions,
              'userAnswers': _selectedAnswers,
              'timeTaken': timeTaken,
            },
          );
        }
      });
    }
  }

  void _handleAnswer(int questionIndex, String selectedOption) {
    if (mode == 'practice' && _selectedAnswers.containsKey(questionIndex)) {
       return;
    }
    setState(() {
      _selectedAnswers[questionIndex] = selectedOption;
    });
  }
  
  void _goToNextPage() {
    if (_currentPage < questions.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
    }
  }

  void _goToPreviousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeIn,
    );
  }
  
  Future<void> _showExitDialog() async {
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Quiz?'),
        content: const Text('Are you sure you want to exit? Your current attempt will be submitted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Continue Test')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, true); 
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Submit & Exit'),
          ),
        ],
      ),
    );
    
    if (shouldPop ?? false) {
      _submitQuiz();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _timer?.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) {
        if (didPop) return;
        _showExitDialog();
      },
      child: Scaffold(
        backgroundColor: Colors.white, 
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.black),
          title: Column(
            children: [
              Text(
                topicName,
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              if (mode == 'test')
                Text(
                  'Time Left: $_timerText',
                  style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600),
                ),
            ],
          ),
        ),
        body: PageView.builder(
          physics: const BouncingScrollPhysics(),
          controller: _pageController,
          itemCount: questions.length,
          onPageChanged: (index) {
            setState(() {
              _currentPage = index;
            });
          },
          itemBuilder: (context, index) {
            final question = questions[index];
            return _buildQuestionCard(question, index);
          },
        ),
        bottomNavigationBar: _buildBottomNavBar(),
      ),
    );
  }

  Widget _buildQuestionCard(Question question, int index) {
    final bool isAnswered = _selectedAnswers.containsKey(index);
    
    String correctAnswer = "";
    if (question.correctAnswerIndex >= 0 && question.correctAnswerIndex < question.options.length) {
        correctAnswer = question.options[question.correctAnswerIndex];
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Q ${index + 1}: ${question.questionText}', 
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, height: 1.4),
                ),
              ),
              
              if (_canEdit)
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.red),
                  tooltip: "Edit Question",
                  onPressed: () {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => AdminEditDialog(
                        question: question,
                        
                        onUpdateSuccess: (newQ, newOpts, newAns, newExp) {
                          setState(() {
                            // 🔥 FIXED: subjectId hata diya hai yahan se
                            questions[index] = Question(
                              id: question.id,
                              questionText: newQ, 
                              options: newOpts,   
                              correctAnswerIndex: newAns, 
                              explanation: newExp, 
                              
                              topicId: question.topicId,
                              // subjectId: question.subjectId, // ❌ REMOVED THIS
                            );
                          });
                        },
                      ),
                    );
                  },
                ),
            ],
          ),

          const SizedBox(height: 24),
          
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: question.options.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 12),
            itemBuilder: (ctx, optIndex) {
              final optionText = question.options[optIndex];
              return _buildOptionItem(index, optionText, isAnswered, correctAnswer);
            },
          ),
          
          const SizedBox(height: 20),
          
          if (mode == 'practice' && isAnswered && question.explanation.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("💡 Explanation", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  const SizedBox(height: 8),
                  Text(question.explanation),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOptionItem(int index, String optionText, bool isAnswered, String correctAnswer) {
    Color borderColor = Colors.grey.shade300;
    Color bgColor = Colors.white;
    Color textColor = Colors.black87;
    Widget? trailingIcon;

    final bool isSelected = _selectedAnswers[index] == optionText;

    if (isAnswered) {
      if (mode == 'practice') {
        if (optionText == correctAnswer) {
          borderColor = Colors.green;
          bgColor = Colors.green.shade50;
          trailingIcon = const Icon(Icons.check_circle, color: Colors.green);
        } else if (isSelected) {
          borderColor = Colors.red;
          bgColor = Colors.red.shade50;
          trailingIcon = const Icon(Icons.cancel, color: Colors.red);
        }
      } else { 
        if (isSelected) {
          borderColor = const Color(0xFF6750A4);
          bgColor = const Color(0xFFF3EDF7);
          textColor = const Color(0xFF6750A4);
        }
      }
    }

    return InkWell(
      onTap: () => _handleAnswer(index, optionText),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                optionText, 
                style: TextStyle(fontSize: 16, color: textColor, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal),
              ),
            ),
            if (trailingIcon != null) trailingIcon,
          ],
        ),
      ),
    );
  }
  
  Widget _buildBottomNavBar() {
    bool isLastQuestion = _currentPage == questions.length - 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton(
            onPressed: _currentPage == 0 ? null : _goToPreviousPage,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade200,
              foregroundColor: Colors.black,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: const Text('Previous'),
          ),
          
          Text(
            '${_currentPage + 1}/${questions.length}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),

          ElevatedButton(
            onPressed: isLastQuestion ? _submitQuiz : _goToNextPage,
            style: ElevatedButton.styleFrom(
              backgroundColor: isLastQuestion ? Colors.green : const Color(0xFF6750A4),
              foregroundColor: Colors.white,
              elevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: Text(isLastQuestion ? 'Submit' : 'Next'),
          ),
        ],
      ),
    );
  }
}
