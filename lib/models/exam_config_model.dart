// models/exam_config_model.dart

class ExamConfig {
  final String examName;
  final String subject;
  final String duration; // e.g., "120 Mins"
  final String totalMarks;
  final String date;
  final String watermarkText;
  final List<String> instructions;

  ExamConfig({
    required this.examName,
    required this.subject,
    required this.duration,
    required this.totalMarks,
    required this.date,
    required this.watermarkText,
    required this.instructions,
  });
}
