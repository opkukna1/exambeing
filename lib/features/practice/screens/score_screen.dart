import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../../../models/question_model.dart';

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
  
  // Ad-related variables and functions have been removed.

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

  // initState and dispose methods related to the ad are also removed.

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
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareScoreCard(context),
          ),
        ],
      ),
      // The main Column is replaced by a direct child since the ad widget is gone.
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
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.list_alt_rounded),
                    label: const Text('View Detailed Solution'),
                    onPressed: () {
                      context.push('/solutions', extra: {
                        'questions': widget.questions,
                        'userAnswers': widget.userAnswers,
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      // The ad banner container at the bottom has been removed.
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

