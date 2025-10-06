import 'package:cloud_firestore/cloud_firestore.dart';

class Schedule {
  final String id;
  final String title;
  final String content;
  final Timestamp timestamp;
  final String subjectId; // FIX: This field was missing

  Schedule({
    required this.id,
    required this.title,
    required this.content,
    required this.timestamp,
    required this.subjectId, // FIX: Added to the constructor
  });

  factory Schedule.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Schedule(
      id: doc.id,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      subjectId: data['subjectId'] ?? '', // FIX: Reading the field from Firestore
    );
  }
}
