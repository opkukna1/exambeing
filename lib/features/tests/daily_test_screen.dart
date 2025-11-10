import 'dart:async'; // Timer ke liye zaroori hai
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart'; // Result page par jaane ke liye

// Model class (aap isse alag file mein bhi rakh sakte ho)
class TestQuestion {
  final String id;
  final String questionText;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  TestQuestion({
    required this.id,
    required this.questionText,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  factory TestQuestion.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    // Data safe tareeke se padhna
    final optionsData = data['options'] as List<dynamic>?;
    return TestQuestion(
      id: doc.id,
      questionText: data['QuestionText'] ?? 'Question not found',
      options: optionsData?.map((e) => e.toString()).toList() ?? [], // Safe List
      correctIndex: (data['CorrectIndex'] as num?)?.toInt() ?? 0,
      explanation: data['Explanation'] ?? '',
    );
  }
}


class DailyTestScreen extends StatefulWidget {
  final List<String> questionIds;
  
  const DailyTestScreen({super.key, required this.questionIds});

  @override
  State<DailyTestScreen> createState() => _DailyTestScreenState();
}

class _DailyTestScreenState extends State<DailyTestScreen> {
  late Future<List<TestQuestion>> _questionsFuture;
  final PageController _pageController = PageController();
  
  // State variables
  final Map<String, int> _userAnswers = {}; // User ke answers save karne ke liye
  int _currentIndex = 0;
  bool _isLoading = true;

  // Timer variables
  Timer? _timer;
  int _remainingSeconds = 1200; // 20 minutes * 60 seconds

  @override
  void initState() {
    super.initState();
    _questionsFuture = _fetchQuestions();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel(); // Timer ko band karna zaroori hai
    _pageController.dispose();
    super.dispose();
  }

  // --- Data Fetching ---
  Future<List<TestQuestion>> _fetchQuestions() async {
    setState(() { _isLoading = true; });
    try {
      final List<TestQuestion> fetchedQuestions = [];
      for (String id in widget.questionIds) {
        if (id.isEmpty) continue; // Khali ID skip karo
        final doc = await FirebaseFirestore.instance
            .collection('todayquestions')
            .doc(id)
            .get();
        if (doc.exists) {
          fetchedQuestions.add(TestQuestion.fromSnapshot(doc));
        }
      }
      
      // Agar questions 20 se kam mile, toh timer bhi kam kar do (ya default rakho)
      // Abhi hum 20 min hi rakhenge
      
      setState(() { _isLoading = false; });
      return fetchedQuestions;
    } catch (e) {
      setState(() { _isLoading = false; });
      print("Error fetching questions: $e");
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
    // 1200 seconds -> 20:00
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }

  // --- Back Button Dialog Logic ---
  Future<bool> _showExitDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Test?'),
        content: const Text('Are you sure you want to end the test?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false), // "Continue"
            child: const Text('Continue'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true), // "Submit"
            child: const Text('Submit Test'),
          ),
        ],
      ),
    );
    
    // Agar user 'Submit' dabata hai (result == true)
    if (result == true) {
      _submitTest();
      return true; // Screen se pop hone do
    }
    
    return false; // Screen par hi raho
  }

  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    // Back button press ko rokne ke liye
    return PopScope(
      canPop: false, // Default back button ko disable karo
      onPopInvoked: (didPop) {
        if (didPop) return; // Agar system ne pop kar diya (rare case)
        _showExitDialog(); // Apna dialog dikhao
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Time Left: ${_formatDuration(_remainingSeconds)}'),
          elevation: 1,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : FutureBuilder<List<TestQuestion>>(
                future: _questionsFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('Could not load questions.'));
                  }

                  final questions = snapshot.data!;

                  return Column(
                    children: [
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          // SWIPE ENABLED
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
                      // Navigation Buttons (Screenshot jaisa)
                      _buildNavigationButtons(questions.length),
                    ],
                  );
                },
              ),
      ),
    );
  }

  // --- UI Widgets ---

  // Naya Question Card UI (Screenshot jaisa)
  Widget _buildQuestionCard(TestQuestion question) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question.questionText,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          
          // Custom Option Buttons
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
                        "${String.fromCharCode(65 + optionIndex)}.", // A, B, C, D
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

  // Naya Navigation Bar (Screenshot jaisa)
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
          // Previous Button
          TextButton.icon(
            icon: const Icon(Icons.arrow_back_ios),
            label: const Text('Previous'),
            onPressed: _currentIndex == 0
                ? null // Pehle question par disable
                : () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeIn,
                    );
                  },
          ),
          
          // Progress (2/10)
          Text(
            "${_currentIndex + 1}/$totalQuestions",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          
          // Next / Submit Button
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

  // --- Scoring & Submission ---
  // ⚠️ YEH RAHA UPDATED FUNCTION ⚠️
  void _submitTest() {
    _timer?.cancel(); // Timer roko
    
    // Dobara submit na ho isliye check
    if (!mounted) return;

    // ----- Scoring Logic -----
    double score = 0.0;
    int correct = 0;
    int wrong = 0;
    int unattempted = 0;

    // Questions list ko future se bahar nikalna padega
    _questionsFuture.then((questions) {
      if (questions.isEmpty) return; // Agar question hi nahi toh
      
      for (var q in questions) {
        if (!_userAnswers.containsKey(q.id)) {
          // Unattempted
          unattempted++;
        } else if (_userAnswers[q.id] == q.correctIndex) {
          // Correct
          score += 1.0;
          correct++;
        } else {
          // Wrong
          score -= 0.33;
          wrong++;
        }
      }

      // Negative score ko 0 kar do (optional, but good)
      if (score < 0) score = 0;

      print("Test Submitted! Score: $score");

      // Nayi 'ResultScreen' par saara data bhejo
      if (mounted) {
         context.go('/result-screen', extra: {
           'score': score,
           'correct': correct,
           'wrong': wrong,
           'unattempted': unattempted,
           'questions': questions, // Poori questions ki list
           'userAnswers': _userAnswers, // User ke answers ka map
           'topicName': "Daily Test", // Topic ka naam
         });
      }
    });
  }
}
