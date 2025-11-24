import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

// Hamare models import karo
import 'daily_test_screen.dart'; // 'TestQuestion' model yahan hai
import 'test_list_screen.dart';  // 'TestInfo' model yahan hai

class SeriesTestScreen extends StatefulWidget {
  final TestInfo testInfo;

  const SeriesTestScreen({super.key, required this.testInfo});

  @override
  State<SeriesTestScreen> createState() => _SeriesTestScreenState();
}

class _SeriesTestScreenState extends State<SeriesTestScreen> {
  late Future<List<TestQuestion>> _questionsFuture;
  final PageController _pageController = PageController();
  
  // State variables
  final Map<String, int> _userAnswers = {};
  int _currentIndex = 0;
  bool _isLoading = true;

  // Timer variables
  Timer? _timer;
  late int _remainingSeconds;

  @override
  void initState() {
    super.initState();
    // Timer set karo (Duration minutes mein hai, usko seconds mein convert karo)
    _remainingSeconds = widget.testInfo.duration * 60;
    
    _questionsFuture = _fetchQuestions();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  // --- ⚠️ DEEP NESTED DATA FETCHING LOGIC ⚠️ ---
  Future<List<TestQuestion>> _fetchQuestions() async {
    setState(() { _isLoading = true; });
    try {
      // Hum specific path par jakar questions layenge:
      // testSeriesHome -> Series -> subjects -> Subject -> tests -> Test -> questions
      
      final snapshot = await FirebaseFirestore.instance
          .collection('testSeriesHome')
          .doc(widget.testInfo.seriesId)
          .collection('subjects')
          .doc(widget.testInfo.subjectId)
          .collection('tests')
          .doc(widget.testInfo.id) // Test ID
          .collection('questions') // Sub-collection
          .get();

      final questions = snapshot.docs.map((doc) => TestQuestion.fromSnapshot(doc)).toList();
      
      setState(() { _isLoading = false; });
      return questions;
    } catch (e) {
      setState(() { _isLoading = false; });
      debugPrint("Error fetching questions form nested path: $e");
      return [];
    }
  }

  // --- Timer Logic ---
  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
        _submitTest(); // Time khatam! Auto-submit
      }
    });
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }

  // --- Back Button Dialog ---
  Future<bool> _showExitDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Test?'),
        content: const Text('Are you sure you want to end the test?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continue'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Submit Test'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      _submitTest();
      return true;
    }
    return false;
  }

  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _showExitDialog();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Test ka naam thoda chhota dikhao agar lamba ho
              Flexible(
                child: Text(
                  widget.testInfo.title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '⏱️ ${_formatDuration(_remainingSeconds)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          elevation: 1,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : FutureBuilder<List<TestQuestion>>(
                future: _questionsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  // Error handling agar data na mile
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text(
                              'No questions found inside this test.',
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Path: .../tests/${widget.testInfo.id}/questions',
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final questions = snapshot.data!;

                  return Column(
                    children: [
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          physics: const BouncingScrollPhysics(),
                          itemCount: questions.length,
                          onPageChanged: (index) {
                            setState(() {
                              _currentIndex = index;
                            });
                          },
                          itemBuilder: (context, index) {
                            return _buildQuestionCard(questions[index]);
                          },
                        ),
                      ),
                      _buildNavigationButtons(questions.length),
                    ],
                  );
                },
              ),
      ),
    );
  }

  // --- UI Widgets ---
  Widget _buildQuestionCard(TestQuestion question) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Q${_currentIndex + 1}: ${question.questionText}",
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 24),
          
          ...List.generate(question.options.length, (optionIndex) {
            final optionText = question.options[optionIndex];
            final bool isSelected = _userAnswers[question.id] == optionIndex;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _userAnswers[question.id] = optionIndex;
                  });
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                        : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        "${String.fromCharCode(65 + optionIndex)}.",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Theme.of(context).colorScheme.primary : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(optionText),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons(int totalQuestions) {
    bool isLastQuestion = _currentIndex == totalQuestions - 1;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            icon: const Icon(Icons.arrow_back_ios),
            label: const Text('Previous'),
            onPressed: _currentIndex == 0
                ? null
                : () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeIn,
                    );
                  },
          ),
          Text(
            "${_currentIndex + 1}/$totalQuestions",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          TextButton.icon(
            label: Icon(isLastQuestion ? Icons.check_circle : Icons.arrow_forward_ios),
            icon: Text(isLastQuestion ? 'Submit' : 'Next'),
            iconAlignment: IconAlignment.end,
            style: TextButton.styleFrom(
              foregroundColor: isLastQuestion ? Colors.green : Theme.of(context).colorScheme.primary,
            ),
            onPressed: () {
              if (isLastQuestion) {
                _submitTest();
              } else {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeIn,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // --- Submission Logic ---
  void _submitTest() {
    _timer?.cancel();
    if (!mounted) return;

    double score = 0.0;
    int correct = 0;
    int wrong = 0;
    int unattempted = 0;

    _questionsFuture.then((questions) {
      if (questions.isEmpty) return;
      
      for (var q in questions) {
        if (!_userAnswers.containsKey(q.id)) {
          unattempted++;
        } else if (_userAnswers[q.id] == q.correctIndex) {
          score += 1.0;
          correct++;
        } else {
          score -= 0.33;
          wrong++;
        }
      }

      if (score < 0) score = 0;

      // Result Screen par bhej do
      if (mounted) {
         context.go('/result-screen', extra: {
           'score': score,
           'correct': correct,
           'wrong': wrong,
           'unattempted': unattempted,
           'questions': questions,
           'userAnswers': _userAnswers,
           'topicName': widget.testInfo.title, // Test ka naam pass karo
         });
      }
    });
  }
}
