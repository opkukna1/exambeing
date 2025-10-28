import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:screenshot/screenshot.dart';
import '../../../helpers/database_helper.dart';
import '../../../models/question_model.dart';

class SolutionsScreen extends StatefulWidget {
  final List<Question> questions;
  final Map<int, String> userAnswers;

  const SolutionsScreen({
    super.key,
    required this.questions,
    required this.userAnswers,
  });

  @override
  State<SolutionsScreen> createState() => _SolutionsScreenState();
}

class _SolutionsScreenState extends State<SolutionsScreen> {
  late Set<String> _bookmarkedQuestionTexts;
  bool _isLoading = true;
  late List<ScreenshotController> _screenshotControllers;

  @override
  void initState() {
    super.initState();
    _screenshotControllers = List.generate(widget.questions.length, (index) => ScreenshotController());
    _loadBookmarkStatus();
  }

  Future<void> _loadBookmarkStatus() async {
    final bookmarkedQuestions = await DatabaseHelper.instance.getAllBookmarkedQuestions();
    _bookmarkedQuestionTexts = bookmarkedQuestions.map((q) => q.questionText).toSet();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _toggleBookmark(Question question) async {
    final isBookmarked = _bookmarkedQuestionTexts.contains(question.questionText);
    String message = '';

    try {
      if (isBookmarked) {
        await DatabaseHelper.instance.unbookmarkQuestion(question.questionText);
        _bookmarkedQuestionTexts.remove(question.questionText);
        message = 'Bookmark removed';
      } else {
        await DatabaseHelper.instance.bookmarkQuestion(question);
        _bookmarkedQuestionTexts.add(question.questionText);
        message = 'Question Bookmarked!';
      }
    } on Exception catch (e) {
      message = e.toString().replaceAll('Exception: ', '');
    }

    // Check if the widget is still mounted before calling setState
    if(mounted) {
      setState(() {});
    }
    
    // Check if the widget is still mounted before showing SnackBar
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }


  void _shareQuestionAsImage(BuildContext context, ScreenshotController controller, String questionText) async {
    // ⬇️ Capture karte waqt background color theme se lo ⬇️
    final theme = Theme.of(context);
    final Uint8List? image = await controller.capture(
        pixelRatio: 2.0,
        delay: const Duration(milliseconds: 10), // Thoda delay
        context: context, // Context dena zaroori hai theme ke liye
        backgroundColor: theme.cardColor // Card ka background color istemal karo
    );
    // ⬆️=============================================⬆️
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

  @override
  Widget build(BuildContext context) {
    // ⬇️ Theme ko yahaan le lo, baar baar na likhna pade ⬇️
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    // ⬆️=============================================⬆️

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
                final userAnswer = widget.userAnswers[index];
                final correctAnswer = question.options[question.correctAnswerIndex];
                final isCorrect = userAnswer == correctAnswer;
                final bool isBookmarked = _bookmarkedQuestionTexts.contains(question.questionText);
                final controller = _screenshotControllers[index];

                return Screenshot(
                  controller: controller,
                  // ⬇️ Card ka background color theme se lo ⬇️
                  child: Card(
                    // color: theme.cardColor, // <-- Hardcoded color hata diya
                    elevation: 2,
                    // ⬆️==================================⬆️
                    child: Stack(
                      children: [
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: Opacity(
                            opacity: 0.1,
                            child: Image.asset('assets/logo.png', height: 50),
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
                                      // ⬇️ Text color bhi theme se lega ⬇️
                                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                      // ⬆️============================⬆️
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                                          // ⬇️ Icon color theme se lo ⬇️
                                          color: colorScheme.primary,
                                          // ⬆️======================⬆️
                                        ),
                                        onPressed: () => _toggleBookmark(question),
                                        tooltip: 'Bookmark Question',
                                      ),
                                      IconButton(
                                        // ⬇️ Icon color theme se lo ⬇️
                                        icon: Icon(Icons.share_outlined, color: textTheme.bodyMedium?.color?.withOpacity(0.6)),
                                        // ⬆️======================⬆️
                                        onPressed: () => _shareQuestionAsImage(context, controller, question.questionText),
                                        tooltip: 'Share as Image',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              for (var option in question.options)
                                _buildOptionTile(context, option, correctAnswer, userAnswer),
                              const SizedBox(height: 16),
                              if (userAnswer != null)
                                Text(
                                  isCorrect ? 'Your answer is correct' : 'Your answer is incorrect',
                                  style: TextStyle(
                                    color: isCorrect ? Colors.green.shade600 : colorScheme.error, // Error color theme se
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              // ⬇️ Divider ka color bhi theme se lo ⬇️
                              Divider(height: 24, color: theme.dividerColor),
                              // ⬆️===============================⬆️
                              Text(
                                '💡 Explanation:',
                                style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              // ⬇️ Text color bhi theme se lega ⬇️
                              Text(question.explanation, style: textTheme.bodyMedium),
                              // ⬆️============================⬆️
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildOptionTile(BuildContext context, String option, String correctAnswer, String? userAnswer) {
    IconData? icon;
    Color? color;
    // ⬇️ Theme colors ka istemal karo ⬇️
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    Color borderColor = theme.dividerColor; // Default border color
    Color? tileColor = Colors.transparent; // Default background
    Color? textColor = textTheme.bodyMedium?.color; // Default text color
    // ⬆️==============================⬆️

    if (option == correctAnswer) {
      icon = Icons.check_circle;
      color = Colors.green.shade600; // Correct answer hamesha green
      borderColor = color;
      tileColor = color.withOpacity(0.1);
      textColor = color; // Correct text ko green dikhao
    } else if (option == userAnswer) {
      icon = Icons.cancel;
      color = colorScheme.error; // Incorrect answer ke liye theme ka error color
      borderColor = color;
      tileColor = color.withOpacity(0.1);
      textColor = color; // Incorrect text ko error color mein dikhao
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      padding: const EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: tileColor, // Updated background
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor), // Updated border
      ),
      child: Row(
        children: [
          if (icon != null) Icon(icon, color: color, size: 20),
          if (icon != null) const SizedBox(width: 8),
          Expanded(child: Text(option, style: TextStyle(color: textColor))), // Updated text color
        ],
      ),
    );
  }
}
