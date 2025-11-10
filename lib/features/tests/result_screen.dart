import 'dart.typed_data';
import 'package.flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'dart.io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ⚠️ Naye Imports ⚠️
// Hum 'Question' model ki jagah apna 'TestQuestion' model use karenge
import 'daily_test_screen.dart'; 
// Hum 'AdServiceProvider' ki jagah simple navigation use karenge
// (Aap ad provider baad mein add kar sakte hain)


class ResultScreen extends StatefulWidget {
  // Data jo 'DailyTestScreen' se aa raha hai
  final double score;
  final int correct;
  final int wrong;
  final int unattempted;
  final List<TestQuestion> questions;
  final Map<String, int> userAnswers;
  final String topicName;

  const ResultScreen({
    super.key,
    required this.score,
    required this.correct,
    required this.wrong,
    required this.unattempted,
    required this.questions,
    required this.userAnswers,
    this.topicName = "Daily Test", // Topic ka naam
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isUpdatingStats = true;

  @override
  void initState() {
    super.initState();
    _updateUserStats();
  }

  // Solutions page par jaane ke liye naya function
  void _navigateToSolutions() {
    if (!mounted) return;
    // Hum 'SolutionScreen' ko apna data pass kar rahe hain
    context.push('/solution-screen', extra: {
      'questions': widget.questions,
      'userAnswers': widget.userAnswers,
    });
  }

  // User stats update karne ka logic
  Future<void> _updateUserStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isUpdatingStats = false);
      return;
    }

    final userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        
        // Data ko apne variable names se update kiya
        final int totalQuestions = widget.questions.length;
        final int correctCount = widget.correct;

        if (!userDoc.exists) {
          transaction.set(userRef, {
            'tests_taken': 1,
            'total_questions_answered': totalQuestions,
            'total_correct_answers': correctCount,
            'email': user.email,
            'name': user.displayName,
          });
        } else {
          final data = userDoc.data()!;
          int newTestsTaken = (data['tests_taken'] ?? 0) + 1;
          int newQuestionsAnswered =
              (data['total_questions_answered'] ?? 0) + totalQuestions;
          int newCorrectAnswers =
              (data['total_correct_answers'] ?? 0) + correctCount;

          transaction.update(userRef, {
            'tests_taken': newTestsTaken,
            'total_questions_answered': newQuestionsAnswered,
            'total_correct_answers': newCorrectAnswers,
          });
        }
      });
    } catch (e) {
      debugPrint("Stats update failed: $e");
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStats = false);
      }
    }
  }

  // Score card share karne ka logic
  void _shareScoreCard(BuildContext context) async {
    final Uint8List? image = await _screenshotController.capture();
    if (image == null) return;

    final directory = await getTemporaryDirectory();
    final imagePath = await File('${directory.path}/score_card.png').writeAsBytes(image);

    await Share.shareXFiles(
      [XFile(imagePath.path)],
      text: "Check out my score in the ${widget.topicName} quiz!",
    );
  }

  // Feedback logic
  Map<String, dynamic> _getFeedback(double score) {
    if (score >= 80) {
      return {'message': 'Outstanding! 🏆', 'color': Colors.green};
    } else if (score >= 60) {
      return {'message': 'Great Job! 👍', 'color': Colors.blue};
    } else if (score >= 40) {
      return {'message': 'Good Effort!', 'color': Colors.orange};
    } else {
      return {'message': 'Keep Practicing!', 'color': Colors.red};
    }
  }

  @override
  Widget build(BuildContext context) {
    final int totalQuestions = widget.questions.length;
    final double scorePercent = totalQuestions > 0 ? (widget.correct / totalQuestions) * 100 : 0;
    final feedback = _getFeedback(scorePercent);
    
    // Score card ka UI
    Widget scoreCard = Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Quiz Result: ${widget.topicName}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn('Correct', '${widget.correct}', Colors.green),
                  _buildStatColumn('Wrong', '${widget.wrong}', Colors.red),
                  _buildStatColumn('Unattempted', '${widget.unattempted}', Colors.grey),
                ],
              ),
              
              const SizedBox(height: 20),
              
              Text(
                'Final Score',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                widget.score.toStringAsFixed(2),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: widget.score >= 0 ? Colors.blue : Colors.red,
                    ),
              ),
              const SizedBox(height: 20),
              Text(
                feedback['message'],
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: feedback['color'],
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          
          Positioned(
            bottom: 0,
            right: 0,
            child: Opacity(
              opacity: 0.2,
              child: Image.asset(
                'assets/logo.png', // Make sure logo 'assets/logo.png' par hai
                height: 40,
                errorBuilder: (c, e, s) => SizedBox(), // Agar logo na mile toh error na aaye
              ),
            ),
          )
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Result'),
        automaticallyImplyLeading: false,
        actions: [
          if (_isUpdatingStats)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () => _shareScoreCard(context),
            ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Screenshot(
                  controller: _screenshotController,
                  child: scoreCard,
                ),
                
                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.home),
                    label: const Text('Go to Home'),
                    onPressed: () => context.go('/home'), // '/home' route par bhej dega
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.list_alt_rounded),
                    label: const Text('View Detailed Solution'),
                    // AdProvider hata diya, simple navigation rakha hai
                    onPressed: () {
                      _navigateToSolutions(); // Seedha solution screen par jao
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String title, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(title),
      ],
    );
  }
}
