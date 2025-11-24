import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../../../models/question_model.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ✅ 1. AdManager Import kiya (Simple aur Fast)
import 'package:exambeing/services/ad_manager.dart';

class ScoreScreen extends StatefulWidget {
  final int totalQuestions;
  final double finalScore;
  final int correctCount;
  final int wrongCount;
  final int unattemptedCount;
  final String topicName;
  final List<Question> questions;
  final Map<int, String> userAnswers;

  const ScoreScreen({
    super.key,
    required this.totalQuestions,
    required this.finalScore,
    required this.correctCount,
    required this.wrongCount,
    required this.unattemptedCount,
    required this.topicName,
    required this.questions,
    required this.userAnswers,
  });

  @override
  State<ScoreScreen> createState() => _ScoreScreenState();
}

class _ScoreScreenState extends State<ScoreScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isUpdatingStats = true;

  @override
  void initState() {
    super.initState();
    _updateUserStats();
    
    // Optional: Agar aap chahte hain ki Result screen par aate hi 
    // agla Ad load hona shuru ho jaye taaki button dabane par turant dikhe
    AdManager.loadInterstitialAd();
  }

  // Solutions page par jaane ke liye function
  void _navigateToSolutions() {
    if (!mounted) return;
    context.push('/solutions', extra: {
      'questions': widget.questions,
      'userAnswers': widget.userAnswers,
    });
  }

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

        if (!userDoc.exists) {
          transaction.set(userRef, {
            'tests_taken': 1,
            'total_questions_answered': widget.totalQuestions,
            'total_correct_answers': widget.correctCount,
            'email': user.email,
            'name': user.displayName,
          });
        } else {
          final data = userDoc.data()!;
          int newTestsTaken = (data['tests_taken'] ?? 0) + 1;
          int newQuestionsAnswered =
              (data['total_questions_answered'] ?? 0) + widget.totalQuestions;
          int newCorrectAnswers =
              (data['total_correct_answers'] ?? 0) + widget.correctCount;

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
    final double scorePercent = widget.totalQuestions > 0 ? (widget.correctCount / widget.totalQuestions) * 100 : 0;
    final feedback = _getFeedback(scorePercent);
    
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
                  _buildStatColumn('Correct', '${widget.correctCount}', Colors.green),
                  _buildStatColumn('Wrong', '${widget.wrongCount}', Colors.red),
                  _buildStatColumn('Unattempted', '${widget.unattemptedCount}', Colors.grey),
                ],
              ),
              
              const SizedBox(height: 20),
              
              Text(
                'Final Score',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                widget.finalScore.toStringAsFixed(2),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: widget.finalScore >= 0 ? Colors.blue : Colors.red,
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
                'assets/logo.png',
                height: 40,
                errorBuilder: (context, error, stackTrace) => const SizedBox(), // Error handle kiya
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
                    onPressed: () => context.go('/'),
                  ),
                ),
                const SizedBox(height: 12),
                
                // ✅ 2. "View Detailed Solution" Button with Ad Logic
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.list_alt_rounded),
                    label: const Text('View Detailed Solution'),
                    onPressed: () {
                      // AdManager ko call kiya
                      AdManager.showInterstitialAd(() {
                        // Ad band hone ke baad ye chalega
                        _navigateToSolutions();
                      });
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
