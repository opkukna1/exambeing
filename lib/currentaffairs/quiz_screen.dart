import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

class QuizScreen extends StatefulWidget {
  final List<dynamic> questions;
  final String title;

  const QuizScreen({super.key, required this.questions, required this.title});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _currentIndex = 0;
  int _score = 0;
  int? _selectedAnswerIndex;
  bool _isAnswered = false;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _handleAnswer(int index) {
    if (_isAnswered) return;

    setState(() {
      _selectedAnswerIndex = index;
      _isAnswered = true;
      if (index == widget.questions[_currentIndex]['correctIndex']) {
        _score++;
      }
    });
  }

  void _nextQuestion() {
    if (_currentIndex < widget.questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedAnswerIndex = null;
        _isAnswered = false;
      });
    } else {
      _showResultDialog();
    }
  }

  void _showResultDialog() {
    if (_score >= widget.questions.length / 2) {
      _confettiController.play();
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("📝 Result", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange],
            ),
            Text(
              "You Scored: $_score / ${widget.questions.length}",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepPurple),
            ),
            const SizedBox(height: 10),
            Text(_score > 7 ? "Excellent Work! 🏆" : "Keep Practicing! 📚"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to News
            },
            child: const Text("Finish", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentQuestion = widget.questions[_currentIndex];
    double progress = (_currentIndex + 1) / widget.questions.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Progress Bar
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.deepPurple.withOpacity(0.1),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.orangeAccent),
            minHeight: 6,
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question Counter
                  Text(
                    "Question ${_currentIndex + 1} of ${widget.questions.length}",
                    style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  
                  // Question Text
                  Text(
                    currentQuestion['question'],
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF2D3142)),
                  ),
                  const SizedBox(height: 30),
                  
                  // Options List
                  ...List.generate(4, (index) {
                    bool isCorrect = index == currentQuestion['correctIndex'];
                    bool isSelected = index == _selectedAnswerIndex;
                    
                    Color cardColor = Colors.white;
                    Color borderColor = Colors.grey.shade300;
                    
                    if (_isAnswered) {
                      if (isCorrect) {
                        cardColor = Colors.green.shade50;
                        borderColor = Colors.green;
                      } else if (isSelected) {
                        cardColor = Colors.red.shade50;
                        borderColor = Colors.red;
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () => _handleAnswer(index),
                        borderRadius: BorderRadius.circular(15),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: borderColor, width: 2),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 15,
                                backgroundColor: isSelected ? Colors.deepPurple : Colors.grey.shade200,
                                child: Text(
                                  String.fromCharCode(65 + index), // A, B, C, D
                                  style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black),
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Text(
                                  currentQuestion['options'][index],
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                              ),
                              if (_isAnswered && isCorrect) const Icon(Icons.check_circle, color: Colors.green),
                              if (_isAnswered && isSelected && !isCorrect) const Icon(Icons.cancel, color: Colors.red),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  
                  // Explanation Card
                  if (_isAnswered)
                    Container(
                      margin: const EdgeInsets.only(top: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.lightbulb, color: Colors.blue, size: 20),
                              SizedBox(width: 8),
                              Text("Explanation", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(currentQuestion['explanation'], style: const TextStyle(fontSize: 14, color: Colors.black87)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // Next Button
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isAnswered ? _nextQuestion : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 5,
                ),
                child: Text(
                  _currentIndex == widget.questions.length - 1 ? "Finish Test" : "Next Question",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
