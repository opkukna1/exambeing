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

    setState(() {});
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  void _shareQuestionAsImage(BuildContext context, ScreenshotController controller, String questionText) async {
    final Uint8List? image = await controller.capture(pixelRatio: 2.0);
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
                  child: Card(
                    color: Colors.white,
                    elevation: 2,
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
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                        onPressed: () => _toggleBookmark(question),
                                        tooltip: 'Bookmark Question',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.share_outlined),
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
                                    color: isCorrect ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              const Divider(height: 24),
                              Text(
                                '💡 Explanation:',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(question.explanation),
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

    if (option == correctAnswer) {
      icon = Icons.check_circle;
      color = Colors.green;
    } else if (option == userAnswer) {
      icon = Icons.cancel;
      color = Colors.red;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      padding: const EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: color?.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color ?? Colors.grey.shade300),
      ),
      child: Row(
        children: [
          if (icon != null) Icon(icon, color: color, size: 20),
          if (icon != null) const SizedBox(width: 8),
          Expanded(child: Text(option)),
        ],
      ),
    );
  }
}
