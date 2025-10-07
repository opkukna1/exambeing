import 'package:flutter/material.dart';
import 'package:exambeing/models/question_model.dart'; // ✅ FIX: Using package import

class BookmarkedQuestionDetailScreen extends StatelessWidget {
  final Question question;
  const BookmarkedQuestionDetailScreen({super.key, required this.question});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookmarked Question'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(question.questionText, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            for (var option in question.options)
              _buildOptionTile(context, option, question.options[question.correctAnswerIndex]),
            const Divider(height: 32),
            Text('💡 Explanation:', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(question.explanation, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile(BuildContext context, String option, String correctAnswer) {
    final bool isCorrect = option == correctAnswer;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: isCorrect ? Colors.green.withOpacity(0.1) : null,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isCorrect ? Colors.green : Colors.grey.shade300),
      ),
      child: Row(
        children: [
          // ✅ FIX: Added 'const' to the Icon for better performance
          if (isCorrect) const Icon(Icons.check_circle, color: Colors.green, size: 20),
          if (isCorrect) const SizedBox(width: 8),
          Expanded(child: Text(option)),
        ],
      ),
    );
  }
}
