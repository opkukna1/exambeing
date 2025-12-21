import 'package:cloud_firestore/cloud_firestore.dart';

class Question {
  String id;
  String questionText;
  List<String> options; // ✅ Changed: Fixed separate options to a List
  int correctIndex;     // ✅ Changed: String "A" ki jagah int Index (0,1,2,3)
  String explanation;

  Question({
    required this.id,
    required this.questionText,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'question': questionText, // Database expects 'question'
      'options': options,
      'correctIndex': correctIndex,
      'explanation': explanation,
    };
  }

  factory Question.fromMap(Map<String, dynamic> map) {
    return Question(
      id: map['id'] ?? '',
      // Handle both keys just in case
      questionText: map['question'] ?? map['questionText'] ?? '', 
      
      // Dynamic List conversion
      options: List<String>.from(map['options'] ?? []), 
      
      correctIndex: map['correctAnswerIndex'] ?? map['correctIndex'] ?? 0,
      explanation: map['explanation'] ?? map['solution'] ?? '',
    );
  }
}

class TestModel {
  String id;
  String subject; // Will map 'testTitle' to this
  DateTime scheduledAt;
  List<Question> questions;
  Map<String, dynamic> settings; // ✅ Added: For Timer, Positive/Negative Marks

  TestModel({
    required this.id,
    required this.subject,
    required this.scheduledAt,
    required this.questions,
    required this.settings,
  });

  Map<String, dynamic> toMap() {
    return {
      'testTitle': subject,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'questions': questions.map((x) => x.toMap()).toList(),
      'settings': settings,
    };
  }

  factory TestModel.fromMap(Map<String, dynamic> map, String docId) {
    return TestModel(
      id: docId,
      // CreateScreen saves 'testTitle', Model uses 'subject'
      subject: map['testTitle'] ?? map['subject'] ?? 'Untitled Test',
      
      // Fallback for date
      scheduledAt: (map['scheduledAt'] ?? map['unlockTime'] ?? Timestamp.now()).toDate(),
      
      questions: map['questions'] != null
          ? List<Question>.from(
              (map['questions'] as List<dynamic>).map((x) => Question.fromMap(x)))
          : [],
          
      // Load Settings (Duration, Marks)
      settings: map['settings'] ?? {}, 
    );
  }
}
