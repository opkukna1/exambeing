// lib/core/local_data_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Question {
  final String subject;
  final String topic;
  final String questionText;
  final List<String> options; // FIX: ऑप्शंस अब एक लिस्ट है
  final String correctOption;
  final String? source; // FIX: नया फील्ड
  final String? explanation; // FIX: नया फील्ड

  Question({
    required this.subject,
    required this.topic,
    required this.questionText,
    required this.options,
    required this.correctOption,
    this.source,
    this.explanation,
  });

  factory Question.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Question(
      subject: data['Subject'] ?? '',
      topic: data['Topic'] ?? '',
      questionText: data['Question'] ?? '',
      // FIX: फायरबेस से ऑप्शंस की लिस्ट को पढ़ें
      options: List<String>.from(data['options'] ?? []),
      correctOption: data['CorrectOption'] ?? '',
      source: data['source'], // FIX: नया फील्ड
      explanation: data['explanation'], // FIX: नया फील्ड
    );
  }
}

class FirebaseDataService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ये सभी फंक्शन अब नेस्टेड कलेक्शन के साथ काम करेंगे
  Future<List<String>> getSubjects() async {
    QuerySnapshot snapshot = await _db.collection('Subjects').get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  Future<List<String>> getTopicsForSubject(String subject) async {
    QuerySnapshot snapshot = await _db
        .collection('Subjects')
        .doc(subject)
        .collection('Topics')
        .get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  Future<List<Question>> getQuestionsForTopic(String subject, String topic) async {
    QuerySnapshot snapshot = await _db
        .collection('Subjects')
        .doc(subject)
        .collection('Topics')
        .doc(topic)
        .collection('questions')
        .get();
    return snapshot.docs.map((doc) => Question.fromFirestore(doc)).toList();
  }
}
