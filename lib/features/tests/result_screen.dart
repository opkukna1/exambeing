import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// TestQuestion Model Import
import 'daily_test_screen.dart'; 

// ✅ AdManager Import
import 'package:exambeing/services/ad_manager.dart';

class ResultScreen extends StatefulWidget {
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
    this.topicName = "Daily Test",
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> with SingleTickerProviderStateMixin {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isUpdatingStats = true;
  late AnimationController _animController;
  late Animation<double> _scoreAnimation;

  @override
  void initState() {
    super.initState();
    _updateUserStats();
    
    // ✅ Animation Setup
    _animController = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    
    // Calculate percentage for animation (0.0 to 1.0)
    double percentage = widget.questions.isNotEmpty 
        ? (widget.correct / widget.questions.length) 
        : 0.0;
        
    _scoreAnimation = Tween<double>(begin: 0.0, end: percentage).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCirc)
    );

    _animController.forward();

    // ✅ Ad Pre-load
    AdManager.loadInterstitialAd();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _navigateToSolutions() {
    if (!mounted) return;
    context.push('/solution-screen', extra: {
      'questions': widget.questions,
      'userAnswers': widget.userAnswers,
    });
  }

  void _navigateToHome() {
    if (mounted) {
      context.go('/');
    }
  }

  Future<void> _updateUserStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isUpdatingStats = false);
      return;
    }

    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        final int totalQuestions = widget.questions.length;
        final int correctCount = widget.correct;

        if (!userDoc.exists) {
          transaction.set(userRef, {
            'tests_taken': 1,
            'total_questions_answered': totalQuestions,
            'total_correct_answers': correctCount,
          });
        } else {
          final data = userDoc.data()!;
          transaction.update(userRef, {
            'tests_taken': (data['tests_taken'] ?? 0) + 1,
            'total_questions_answered': (data['total_questions_answered'] ?? 0) + totalQuestions,
            'total_correct_answers': (data['total_correct_answers'] ?? 0) + correctCount,
          });
        }
      });
    } catch (e) {
      debugPrint("Stats update failed: $e");
    } finally {
      if (mounted) setState(() => _isUpdatingStats = false);
    }
  }

  void _shareScoreCard() async {
    final Uint8List? image = await _screenshotController.capture();
    if (image == null) return;

    final directory = await getTemporaryDirectory();
    final imagePath = await File('${directory.path}/result_card.png').writeAsBytes(image);

    await Share.shareXFiles(
      [XFile(imagePath.path)],
      text: "I scored ${widget.score} in ${widget.topicName}! Can you beat me? 🔥 #ExamBeing",
    );
  }

  @override
  Widget build(BuildContext context) {
    final int totalQ = widget.questions.length;
    final double percentageVal = totalQ > 0 ? (widget.correct / totalQ) * 100 : 0;
    
    // Determine Color & Message
    Color themeColor;
    String message;
    if (percentageVal >= 80) {
      themeColor = Colors.green;
      message = "Outstanding! 🏆";
    } else if (percentageVal >= 60) {
      themeColor = Colors.blue;
      message = "Great Job! 👏";
    } else if (percentageVal >= 40) {
      themeColor = Colors.orange;
      message = "Good Effort! 👍";
    } else {
      themeColor = Colors.redAccent;
      message = "Keep Practicing! 💪";
    }

    return PopScope(
      canPop: false, 
      onPopInvoked: (didPop) {
        if (didPop) return;
        _navigateToHome(); 
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50], // Light background
        appBar: AppBar(
          title: const Text("Result Analysis", style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.share_rounded, color: Colors.black),
              onPressed: _shareScoreCard,
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                // 📸 SCREENSHOT AREA STARTS
                Screenshot(
                  controller: _screenshotController,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5)),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(widget.topicName, style: const TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 20),
                        
                        // 🟢 CIRCULAR SCORE INDICATOR
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 180,
                              height: 180,
                              child: AnimatedBuilder(
                                animation: _scoreAnimation,
                                builder: (context, child) {
                                  return CircularProgressIndicator(
                                    value: _scoreAnimation.value,
                                    strokeWidth: 15,
                                    backgroundColor: Colors.grey.shade100,
                                    color: themeColor,
                                    strokeCap: StrokeCap.round,
                                  );
                                },
                              ),
                            ),
                            Column(
                              children: [
                                Text(
                                  "${percentageVal.toStringAsFixed(1)}%",
                                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: themeColor),
                                ),
                                Text(
                                  "Score: ${widget.score.toStringAsFixed(1)}",
                                  style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 20),
                        Text(message, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: themeColor)),
                        const SizedBox(height: 30),

                        // 📊 STATS GRID
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatBox("Correct", "${widget.correct}", Colors.green, Icons.check_circle),
                            _buildStatBox("Wrong", "${widget.wrong}", Colors.red, Icons.cancel),
                            _buildStatBox("Skipped", "${widget.unattempted}", Colors.orange, Icons.remove_circle_outline),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
                // 📸 SCREENSHOT AREA ENDS

                const SizedBox(height: 40),

                // 🏠 HOME BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 2,
                    ),
                    onPressed: _navigateToHome,
                    icon: const Icon(Icons.home_rounded),
                    label: const Text("GO TO HOME", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                
                const SizedBox(height: 15),

                // 📝 SOLUTION BUTTON (With Ad)
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      side: const BorderSide(color: Colors.black12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      backgroundColor: Colors.white,
                    ),
                    onPressed: () {
                      AdManager.showInterstitialAd(() {
                        _navigateToSolutions();
                      });
                    },
                    icon: const Icon(Icons.list_alt_rounded, color: Colors.indigo),
                    label: const Text("VIEW SOLUTIONS", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),

                if (_isUpdatingStats)
                  const Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: Text("Updating your profile stats...", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ✨ Helper Widget for Stats
  Widget _buildStatBox(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}
