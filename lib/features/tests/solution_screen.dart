import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:screenshot/screenshot.dart';
import '../../../helpers/database_helper.dart'; // Bookmark ke liye
import 'daily_test_screen.dart'; // Hamara 'TestQuestion' model yahan hai

class SolutionScreen extends StatefulWidget {
  // Data ResultScreen se aa raha hai
  final List<TestQuestion> questions;
  final Map<String, int> userAnswers; // Format: <QuestionID, OptionIndex>

  const SolutionScreen({
    super.key,
    required this.questions,
    required this.userAnswers,
  });

  @override
  State<SolutionScreen> createState() => _SolutionScreenState();
}

class _SolutionScreenState extends State<SolutionScreen> {
  Set<String> _bookmarkedQuestionTexts = {}; // Default khaali set
  bool _isLoading = true;
  late List<ScreenshotController> _screenshotControllers;

  @override
  void initState() {
    super.initState();
    _screenshotControllers = List.generate(widget.questions.length, (index) => ScreenshotController());
    _loadBookmarkStatus();
  }

  // try...catch...finally block taaki DB error par app atke nahi
  Future<void> _loadBookmarkStatus() async {
    try {
      // NOTE: Humein DatabaseHelper mein 'Question' model ki jagah
      // 'TestQuestion' model use karna hoga ya text se match karna hoga.
      // Abhi hum text se match kar rahe hain.
      final bookmarkedQuestions = await DatabaseHelper.instance.getAllBookmarkedQuestions();
      _bookmarkedQuestionTexts = bookmarkedQuestions.map((q) => q.questionText).toSet();
    } catch (e) {
      debugPrint("Error loading bookmarks, but showing solutions anyway: $e");
      _bookmarkedQuestionTexts = {}; // Bookmark list ko khaali set kar do
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // --- Bookmark Logic ---
  // ⚠️ IMPORTANT: Ye tabhi kaam karega jab aapka DatabaseHelper
  // 'TestQuestion' model ko 'Question' model mein convert kar sake.
  // Abhi ke liye hum assume kar rahe hain ki text se kaam chal jayega.
  void _toggleBookmark(TestQuestion question) async {
    final isBookmarked = _bookmarkedQuestionTexts.contains(question.questionText);
    String message = '';

    try {
      if (isBookmarked) {
        await DatabaseHelper.instance.unbookmarkQuestion(question.questionText);
        _bookmarkedQuestionTexts.remove(question.questionText);
        message = 'Bookmark removed';
      } else {
        // DatabaseHelper ko 'Question' model chahiye hoga.
        // Yahan humein conversion karna padega.
        // Abhi ke liye, hum text par hi chalte hain.
        // await DatabaseHelper.instance.bookmarkQuestion(question);
        _bookmarkedQuestionTexts.add(question.questionText);
        message = 'Question Bookmarked! (Note: DB Save skipped for demo)';
      }
    } on Exception catch (e) {
      message = 'Bookmark failed: ${e.toString().replaceAll('Exception: ', '')}';
    }

    if(mounted) {
      setState(() {});
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  // --- Share Logic ---
  void _shareQuestionAsImage(BuildContext context, ScreenshotController controller, String questionText) async {
    final Uint8List? image = await controller.capture(
        pixelRatio: 2.0,
        delay: const Duration(milliseconds: 10),
    );
    if (image == null) return;
    try {
      final directory = await getTemporaryDirectory();
      final imagePath = await File('${directory.path}/question.png').writeAsBytes(image);

      await Share.shareXFiles(
        [XFile(imagePath.path)],
        text: 'Check out this question: $questionText',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error sharing image: $e')));
      }
    }
  }

  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detailed Solutions'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(16.0),
              itemCount: widget.questions.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final question = widget.questions[index];
                
                // --- ⚠️ DATA FIX (YAHAN CHANGES HAIN) ⚠️ ---
                // Data ko apne format mein convert kiya
                final int? userAnswerIndex = widget.userAnswers[question.id]; // User ka index (0, 1, 2...)
                final int correctAnswerIndex = question.correctIndex; // Sahi index (0, 1, 2...)
                final bool isCorrect = userAnswerIndex == correctAnswerIndex;
                final bool isUnattempted = userAnswerIndex == null;
                // --- ---------------------------------- ---
                
                final bool isBookmarked = _bookmarkedQuestionTexts.contains(question.questionText);
                final controller = _screenshotControllers[index];

                return Screenshot(
                  controller: controller,
                  child: Card(
                    elevation: 2,
                    child: Stack(
                      children: [
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: Opacity(
                            opacity: 0.1,
                            // Make sure 'assets/logo.png' exists in your pubspec.yaml
                            child: Image.asset('assets/logo.png', height: 50, errorBuilder: (c, e, s) => SizedBox()),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Q ${index + 1}: ${question.questionText}',
                                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // IconButton(
                                      //   icon: Icon(
                                      //     isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                                      //     color: colorScheme.primary,
                                      //   ),
                                      //   onPressed: () => _toggleBookmark(question),
                                      //   tooltip: 'Bookmark Question',
                                      // ),
                                      IconButton(
                                        icon: Icon(Icons.share_outlined, color: textTheme.bodyMedium?.color?.withOpacity(0.6)),
                                        onPressed: () => _shareQuestionAsImage(context, controller, question.questionText),
                                        tooltip: 'Share as Image',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              
                              // --- ⚠️ OPTIONS FIX (YAHAN CHANGES HAIN) ⚠️ ---
                              ...List.generate(question.options.length, (optionIndex) {
                                return _buildOptionTile(
                                  context,
                                  option: question.options[optionIndex],
                                  currentOptionIndex: optionIndex,
                                  correctAnswerIndex: correctAnswerIndex,
                                  userAnswerIndex: userAnswerIndex,
                                );
                              }),
                              // --- ---------------------------------- ---

                              const SizedBox(height: 16),
                              
                              if (!isUnattempted)
                                Text(
                                  isCorrect ? 'Your answer is correct' : 'Your answer is incorrect',
                                  style: TextStyle(
                                    color: isCorrect ? Colors.green.shade600 : colorScheme.error,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              if (isUnattempted)
                                Text(
                                  'You skipped this question.',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              
                              Divider(height: 24, color: theme.dividerColor),
                              Text(
                                '💡 Explanation:',
                                style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(question.explanation, style: textTheme.bodyMedium),
                            ],
                          ),
                        ),
                      ],
l                    ),
                  ),
                );
              },
            ),
    );
  }

  // --- ⚠️ _buildOptionTile FIX (YAHAN CHANGES HAIN) ⚠️ ---
  Widget _buildOptionTile(
    BuildContext context, {
    required String option,
    required int currentOptionIndex,
    required int correctAnswerIndex,
    required int? userAnswerIndex,
  }) {
    IconData? icon;
    Color? color;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    Color borderColor = theme.dividerColor;
    Color? tileColor = Colors.transparent;
    Color? textColor = textTheme.bodyMedium?.color;

    if (currentOptionIndex == correctAnswerIndex) {
      // Sahi answer
      icon = Icons.check_circle;
      color = Colors.green.shade600;
      borderColor = color;
      tileColor = color.withOpacity(0.1);
      textColor = color;
    } else if (currentOptionIndex == userAnswerIndex) {
      // User ka galat answer
      icon = Icons.cancel;
      color = colorScheme.error;
      borderColor = color;
      tileColor = color.withOpacity(0.1);
      textColor = color;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      padding: const EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          if (icon != null) Icon(icon, color: color, size: 20),
          if (icon == null) const SizedBox(width: 28), // Space banaye rakhne ke liye
          if (icon != null) const SizedBox(width: 8),
          Expanded(child: Text(option, style: TextStyle(color: textColor))),
        ],
      ),
    );
  }
}
