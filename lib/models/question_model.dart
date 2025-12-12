import 'package:cloud_firestore/cloud_firestore.dart';

class Question {
  final String id;
  final String questionText;
  final List<String> options;
  final int correctAnswerIndex;
  final String explanation;
  final String topicId;

  Question({
    required this.id,
    required this.questionText,
    required this.options,
    required this.correctAnswerIndex,
    required this.explanation,
    required this.topicId,
  });

  // ✅ 1. fromFirestore (Firebase ke liye)
  factory Question.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Question(
      id: doc.id,
      questionText: data['questionText'] ?? '',
      options: List<String>.from(data['options'] ?? []),
      correctAnswerIndex: data['correctAnswerIndex'] ?? 0,
      explanation: data['explanation'] ?? '',
      topicId: data['topicId'] ?? '',
    );
  }

  // ✅ 2. fromMap (Local DB / Revision ke liye - Ye missing tha)
  factory Question.fromMap(Map<String, dynamic> map) {
    return Question(
      id: map['id']?.toString() ?? '',
      // RevisionDB mein humne 'question' key use ki thi, 
      // isliye dono check kar rahe hain (fallback ke liye)
      questionText: map['questionText'] ?? map['question'] ?? '',
      options: List<String>.from(map['options'] ?? []),
      
      // Safe parsing for Integer
      correctAnswerIndex: map['correctAnswerIndex'] is int 
          ? map['correctAnswerIndex'] 
          : int.tryParse(map['correctAnswerIndex'].toString()) ?? 0,
          
      // RevisionDB mein humne 'solution' key use ki thi
      explanation: map['explanation'] ?? map['solution'] ?? '',
      topicId: map['topicId'] ?? '',
    );
  }

  // ✅ 3. toMap (Optional - Future use ke liye)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'questionText': questionText,
      'options': options,
      'correctAnswerIndex': correctAnswerIndex,
      'explanation': explanation,
      'topicId': topicId,
    };
  }
}
