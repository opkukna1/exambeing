// lib/models/mcq_bookmark_model.dart

class McqBookmark {
  final int? id;
  final String subject;
  final String topic;
  final String questionText;
  final List<String> options;
  final String correctOption;
  final String explanation;

  McqBookmark({
    this.id,
    required this.subject,
    required this.topic,
    required this.questionText,
    required this.options,
    required this.correctOption,
    required this.explanation,
  });
}
