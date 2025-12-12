import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:exambeing/models/question_model.dart';
import 'package:exambeing/services/ad_manager.dart';
import 'package:exambeing/services/revision_db.dart';

// ✅ CLASS NAME 'ScoreScreen' HONA CHAHIYE (ProfileScreen nahi)
class ScoreScreen extends StatefulWidget {
  final int totalQuestions;
  final double finalScore;
  final int correctCount;
  final int wrongCount;
  final int unattemptedCount;
  final String topicName;
  final List<Question> questions;
  final Map<int, String> userAnswers;
  final Duration timeTaken; 

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
    required this.timeTaken, 
  });

  @override
  State<ScoreScreen> createState() => _ScoreScreenState();
}

class _ScoreScreenState extends State<ScoreScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isProcessing = true;

  @override
  void initState() {
    super.initState();
    _processResult(); 
    AdManager.loadInterstitialAd();
  }

  Future<void> _processResult() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isProcessing = false);
      return;
    }

    try {
      for (var question in widget.questions) {
        String qId = question.id; 
        
        // Handle Answer Key type (String/Int mismatch fix)
        String? selectedAns;
        try {
           selectedAns = widget.userAnswers[int.parse(qId)];
        } catch(e) {
           // Fallback agar key match na ho
        }
        
        bool isWrong = selectedAns != null && selectedAns != question.correctOption;

        if (isWrong) {
          Map<String, dynamic> qData = {
            'id': qId,
            'question': question.questionText, // Correct field name from model
            'options': question.options,
            'correctOption': question.correctOption, // Index or String? Make sure logic matches
            'subSubjectName': widget.topicName, 
            'solution': question.explanation, 
          };

          await RevisionDB.instance.addWrongQuestion(qData, widget.topicName, widget.topicName);
        }
      }

      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        Map<String, dynamic> currentStats = {};
        Map<String, dynamic> currentSubjects = {};

        if (userDoc.exists) {
          final data = userDoc.data()!;
          currentStats = data['stats'] as Map<String, dynamic>? ?? {};
          currentSubjects = currentStats['subjects'] as Map<String, dynamic>? ?? {};
        }

        int newTotalTests = (currentStats['totalTests'] ?? 0) + 1;
        int newTotalQ = (currentStats['totalQuestions'] ?? 0) + widget.totalQuestions;
        int newCorrect = (currentStats['correct'] ?? 0) + widget.correctCount;
        int newWrong = (currentStats['wrong'] ?? 0) + widget.wrongCount;

        String subjectKey = widget.topicName.replaceAll('.', '_'); 
        if (!currentSubjects.containsKey(subjectKey)) {
          currentSubjects[subjectKey] = {'total': 0, 'correct': 0};
        }
        currentSubjects[subjectKey]['total'] += widget.totalQuestions;
        currentSubjects[subjectKey]['correct'] += widget.correctCount;

        transaction.set(userRef, {
          'stats': {
            'totalTests': newTotalTests,
            'totalQuestions': newTotalQ,
            'correct': newCorrect,
            'wrong': newWrong,
            'subjects': currentSubjects,
          },
          'tests_taken': newTotalTests,
          'total_questions_answered': newTotalQ,
          'total_correct_answers': newCorrect,
        }, SetOptions(merge: true));
      });

    } catch (e) {
      debugPrint("Error processing result: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _navigateToSolutions() {
    if (!mounted) return;
    context.push('/solutions', extra: {
      'questions': widget.questions,
      'userAnswers': widget.userAnswers,
    });
  }

  void _shareScoreCard(BuildContext context) async {
    final Uint8List? image = await _screenshotController.capture();
    if (image == null) return;
    final directory = await getTemporaryDirectory();
    final imagePath = await File('${directory.path}/score_card.png').writeAsBytes(image);
    await Share.shareXFiles([XFile(imagePath.path)], text: "Check out my score in the ${widget.topicName} quiz!");
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final String minutes = twoDigits(d.inMinutes.remainder(60));
    final String seconds = twoDigits(d.inSeconds.remainder(60));
    return "${twoDigits(d.inHours)}:$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final double percentage = widget.totalQuestions > 0 
        ? (widget.correctCount / widget.totalQuestions) * 100 
        : 0.0;

    String feedbackMsg = "Keep Practicing!";
    Color feedbackColor = Colors.red;
    if (percentage >= 80) {
      feedbackMsg = "Outstanding! 🏆";
      feedbackColor = Colors.green;
    } else if (percentage >= 60) {
      feedbackMsg = "Great Job! 👍";
      feedbackColor = Colors.blue;
    } else if (percentage >= 40) {
      feedbackMsg = "Good Effort!";
      feedbackColor = Colors.orange;
    }

    Widget scoreCard = Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))
        ]
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Result', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(widget.topicName, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: CircularProgressIndicator(
                      value: percentage / 100,
                      strokeWidth: 10,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(feedbackColor),
                    ),
                  ),
                  Column(
                    children: [
                      Text("${percentage.toInt()}%", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const Text("Score", style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  )
                ],
              ),
              const SizedBox(width: 30),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Final Score", style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    widget.finalScore.toStringAsFixed(1),
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: feedbackColor),
                  ),
                  Text(feedbackMsg, style: TextStyle(color: feedbackColor, fontWeight: FontWeight.w600)),
                ],
              )
            ],
          ),

          const SizedBox(height: 30),
          const Divider(),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDetailItem(Icons.check_circle, "Correct", "${widget.correctCount}", Colors.green),
              _buildDetailItem(Icons.cancel, "Wrong", "${widget.wrongCount}", Colors.red),
              _buildDetailItem(Icons.help, "Skipped", "${widget.unattemptedCount}", Colors.grey),
              _buildDetailItem(Icons.timer, "Time", _formatDuration(widget.timeTaken), Colors.blue),
            ],
          ),

          const SizedBox(height: 20),
          
          Opacity(
            opacity: 0.3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.school, size: 16),
                const SizedBox(width: 5),
                Text("Exambeing", style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          )
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Result Summary'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareScoreCard(context),
          ),
        ],
      ),
      body: _isProcessing 
        ? const Center(child: CircularProgressIndicator()) 
        : SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Screenshot(
                    controller: _screenshotController,
                    child: scoreCard,
                  ),
                  const SizedBox(height: 30),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                          icon: const Icon(Icons.home),
                          label: const Text('Home'),
                          onPressed: () => context.go('/'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.list_alt),
                          label: const Text('Solutions'),
                          onPressed: () {
                            AdManager.showInterstitialAd(() {
                              _navigateToSolutions();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
