import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Required for Admin Check

// ✅ 1. AdManager Import
import 'package:exambeing/services/ad_manager.dart';

class TestQuestion {
  final String id;
  String questionText; // Removed 'final' to allow local updates
  List<String> options; // Removed 'final'
  int correctIndex; // Removed 'final'
  String explanation; // Removed 'final'

  TestQuestion({
    required this.id,
    required this.questionText,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  factory TestQuestion.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final optionsData = data['options'] as List<dynamic>?;
    return TestQuestion(
      id: doc.id,
      questionText: data['QuestionText'] ?? 'Question not found',
      options: optionsData?.map((e) => e.toString()).toList() ?? [],
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
  final Map<String, int> _userAnswers = {};
  int _currentIndex = 0;
  bool _isLoading = true;
  Timer? _timer;
  int _remainingSeconds = 1200; 

  // --- ADMIN VARIABLES ---
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdmin(); // Check if user is admin
    _questionsFuture = _fetchQuestions();
    _startTimer();
  }

  // --- ADMIN CHECK FUNCTION ---
  void _checkAdmin() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email == "opsiddh42@gmail.com") {
      setState(() {
        _isAdmin = true;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<List<TestQuestion>> _fetchQuestions() async {
    setState(() { _isLoading = true; });
    try {
      final List<TestQuestion> fetchedQuestions = [];
      for (String id in widget.questionIds) {
        if (id.isEmpty) continue;
        final doc = await FirebaseFirestore.instance
            .collection('todayquestions')
            .doc(id)
            .get();
        if (doc.exists) {
          fetchedQuestions.add(TestQuestion.fromSnapshot(doc));
        }
      }
      setState(() { _isLoading = false; });
      return fetchedQuestions;
    } catch (e) {
      setState(() { _isLoading = false; });
      debugPrint("Error fetching questions: $e");
      return [];
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
        _submitTest(); 
      }
    });
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }

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

  // ✅ 2. Updated Submit Function with Ad Logic
  void _submitTest() {
    _timer?.cancel();
    
    if (!mounted) return;

    // Scoring Logic (Wait for questions future)
    _questionsFuture.then((questions) {
      if (questions.isEmpty) return;
      
      double score = 0.0;
      int correct = 0;
      int wrong = 0;
      int unattempted = 0;

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

      // ✅ 3. Show Ad Before Navigation
      if (mounted) {
        AdManager.showInterstitialAd(() {
          // Jab ad close ho, tab hi Result Screen par jao
          if (mounted) {
            context.replace('/result-screen', extra: {
              'score': score,
              'correct': correct,
              'wrong': wrong,
              'unattempted': unattempted,
              'questions': questions,
              'userAnswers': _userAnswers,
              'topicName': "Daily Test",
            });
          }
        });
      }
    });
  }

  // --- ADMIN EDIT DIALOG ---
  void _showEditDialog(TestQuestion question) {
    final qController = TextEditingController(text: question.questionText);
    final expController = TextEditingController(text: question.explanation);
    final optControllers = question.options.map((e) => TextEditingController(text: e)).toList();
    int tempCorrectIndex = question.correctIndex;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Edit Question (Admin)"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: qController,
                      decoration: const InputDecoration(labelText: "Question Text"),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 10),
                    ...List.generate(optControllers.length, (index) {
                      return Row(
                        children: [
                          Radio<int>(
                            value: index,
                            groupValue: tempCorrectIndex,
                            onChanged: (val) {
                              setDialogState(() => tempCorrectIndex = val!);
                            },
                          ),
                          Expanded(
                            child: TextField(
                              controller: optControllers[index],
                              decoration: InputDecoration(labelText: "Option ${index + 1}"),
                            ),
                          ),
                        ],
                      );
                    }),
                    const SizedBox(height: 10),
                    TextField(
                      controller: expController,
                      decoration: const InputDecoration(labelText: "Explanation"),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                // DELETE BUTTON
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text("Delete Question?"),
                        actions: [
                          TextButton(onPressed: ()=>Navigator.pop(c, false), child: const Text("No")),
                          TextButton(onPressed: ()=>Navigator.pop(c, true), child: const Text("Yes")),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await FirebaseFirestore.instance.collection('todayquestions').doc(question.id).delete();
                      Navigator.pop(context);
                      // Refresh UI
                      setState(() {
                         _questionsFuture = _fetchQuestions();
                      });
                    }
                  }, 
                  child: const Text("DELETE")
                ),
                
                // SAVE BUTTON
                ElevatedButton(
                  onPressed: () async {
                    await FirebaseFirestore.instance.collection('todayquestions').doc(question.id).update({
                      'QuestionText': qController.text,
                      'Explanation': expController.text,
                      'options': optControllers.map((c) => c.text).toList(),
                      'CorrectIndex': tempCorrectIndex
                    });
                    
                    // Update Local State immediately
                    setState(() {
                      question.questionText = qController.text;
                      question.explanation = expController.text;
                      question.options = optControllers.map((c) => c.text).toList();
                      question.correctIndex = tempCorrectIndex;
                    });
                    
                    Navigator.pop(context);
                  }, 
                  child: const Text("SAVE")
                ),
              ],
            );
          }
        );
      },
    );
  }

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
          title: Text('Time Left: ${_formatDuration(_remainingSeconds)}'),
          elevation: 1,
          actions: [
            if (_isAdmin)
              const Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: Chip(
                  label: Text("ADMIN MODE", style: TextStyle(color: Colors.white, fontSize: 10)),
                  backgroundColor: Colors.red,
                ),
              )
          ],
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

  Widget _buildQuestionCard(TestQuestion question) {
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
                  question.questionText,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // 🔥 ADMIN EDIT ICON
              if (_isAdmin)
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showEditDialog(question),
                )
            ],
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
                // ✅ Submit button press par bhi ad logic chalega
                _showExitDialog(); 
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
}
