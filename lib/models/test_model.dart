import 'package:cloud_firestore/cloud_firestore.dart';

class Question {
  String id;
  String questionText;
  String optionA;
  String optionB;
  String optionC;
  String optionD;
  String correctOption; // "A", "B", "C", or "D"
  String explanation;

  Question({
    required this.id,
    required this.questionText,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.correctOption,
    required this.explanation,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'questionText': questionText,
      'optionA': optionA,
      'optionB': optionB,
      'optionC': optionC,
      'optionD': optionD,
      'correctOption': correctOption,
      'explanation': explanation,
    };
  }

  factory Question.fromMap(Map<String, dynamic> map) {
    return Question(
      id: map['id'] ?? '',
      questionText: map['questionText'] ?? '',
      optionA: map['optionA'] ?? '',
      optionB: map['optionB'] ?? '',
      optionC: map['optionC'] ?? '',
      optionD: map['optionD'] ?? '',
      correctOption: map['correctOption'] ?? '',
      explanation: map['explanation'] ?? '',
    );
  }
}

class TestModel {
  String id;
  String subject;
  String topic;
  DateTime scheduledAt;
  List<Question> questions;

  TestModel({
    required this.id,
    required this.subject,
    required this.topic,
    required this.scheduledAt,
    required this.questions,
  });

  Map<String, dynamic> toMap() {
    return {
      'subject': subject,
      'topic': topic,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'questions': questions.map((x) => x.toMap()).toList(),
    };
  }

  factory TestModel.fromMap(Map<String, dynamic> map, String docId) {
    return TestModel(
      id: docId,
      subject: map['subject'] ?? '',
      topic: map['topic'] ?? '',
      scheduledAt: (map['scheduledAt'] as Timestamp).toDate(),
      questions: List<Question>.from(
        (map['questions'] as List<dynamic>).map((x) => Question.fromMap(x)),
      ),
    );
  }
}
