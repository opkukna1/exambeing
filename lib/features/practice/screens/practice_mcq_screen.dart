import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:exambeing/models/question_model.dart'; // ✅ FIX: Using package import

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

  final PageController _pageController = PageController();
  final Map<int, String> _selectedAnswers = {};
  int _currentPage = 0;
  bool _isSubmitted = false;
  
  Timer? _timer;
  int _start = 0;
  String _timerText = "00:00";

  @override
  void initState() {
    super.initState();
    questions = widget.quizData['questions'] as List<Question>;
    topicName = widget.quizData['topicName'] as String;
    mode = widget.quizData['mode'] as String;

    _pageController.addListener(() {
      final newPage = _pageController.page?.round() ?? 0;
      if (newPage != _currentPage) {
        setState(() {
          _currentPage = newPage;
        });
      }
    });
    
    if (mode == 'test') {
      _start = questions.length * 60;
      startTimer();
    }
  }

  void startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
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
  
  void _submitQuiz() {
    if (_isSubmitted) return;
    setState(() => _isSubmitted = true);
    _timer?.cancel();
    
    double finalScore = 0.0;
    int correctCount = 0;
    int wrongCount = 0;
    int unattemptedCount = 0;

    for (int i = 0; i < questions.length; i++) {
      if (_selectedAnswers.containsKey(i)) {
        String correctAnswer = questions[i].options[questions[i].correctAnswerIndex];
        if (_selectedAnswers[i] == correctAnswer) {
          finalScore += 1.0;
          correctCount++;
        } else {
          finalScore -= 0.33;
          wrongCount++;
        }
      } else {
        unattemptedCount++;
      }
    }

    if (mounted) {
      context.go(
        '/score',
        extra: {
          'totalQuestions': questions.length,
          'finalScore': finalScore,
          'correctCount': correctCount,
          'wrongCount': wrongCount,
          'unattemptedCount': unattemptedCount,
          'topicName': topicName,
          'questions': questions,
          'userAnswers': _selectedAnswers,
        },
      );
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
          TextButton(
            onPressed: () {
              Navigator.pop(context, true); 
            },
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
        appBar: AppBar(
          title: Text(topicName),
          actions: mode == 'test'
              ? [
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: Center(child: Text(_timerText, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                  )
                ]
              : null,
        ),
        body: PageView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          controller: _pageController,
          itemCount: questions.length,
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
    final String correctAnswer = question.options[question.correctAnswerIndex];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Q ${index + 1}: ${question.questionText}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          
          for (var optionText in question.options)
            _buildOptionItem(index, optionText, isAnswered, correctAnswer),
          
          const SizedBox(height: 20),
          if (mode == 'practice' && isAnswered && question.explanation.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("💡 Explanation", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(question.explanation, style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOptionItem(int index, String optionText, bool isAnswered, String correctAnswer) {
    Color borderColor = Colors.grey.shade300;
    Color? tileColor;
    Widget? trailingIcon;

    if (isAnswered) {
      if (mode == 'practice') {
        if (optionText == correctAnswer) {
          borderColor = Colors.green;
          tileColor = Colors.green.withOpacity(0.1);
          trailingIcon = const Icon(Icons.check_circle, color: Colors.green);
        } else if (optionText == _selectedAnswers[index]) {
          borderColor = Colors.red;
          tileColor = Colors.red.withOpacity(0.1);
          trailingIcon = const Icon(Icons.cancel, color: Colors.red);
        }
      } else { // Test Mode
        if (optionText == _selectedAnswers[index]) {
          borderColor = Theme.of(context).colorScheme.primary;
          tileColor = Theme.of(context).colorScheme.primary.withOpacity(0.1);
        }
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      decoration: BoxDecoration(
        color: tileColor,
        border: Border.all(color: borderColor, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _handleAnswer(index, optionText),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Row(
            children: [
              Expanded(child: Text(optionText, style: Theme.of(context).textTheme.bodyLarge)),
              if (trailingIcon != null) trailingIcon,
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildBottomNavBar() {
    bool isLastQuestion = _currentPage == questions.length - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton(
            onPressed: _currentPage == 0 ? null : _goToPreviousPage,
            child: const Text('Previous'),
          ),
          
          Text(
            '${_currentPage + 1}/${questions.length}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
          ),

          // ✅ FIX: This button was completely broken, it has been rebuilt.
          ElevatedButton(
            onPressed: isLastQuestion ? _submitQuiz : _goToNextPage,
            style: ElevatedButton.styleFrom(
              backgroundColor: isLastQuestion ? Colors.green : Theme.of(context).colorScheme.primary,
            ),
            child: Text(isLastQuestion ? 'Submit' : 'Next'),
          ),
        ],
      ),
    );
  }
}
