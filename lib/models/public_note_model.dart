import 'package:cloud_firestore/cloud_firestore.dart';

class PublicNote {
  final String id;
  final String title;
  final String content;
  final String subjectId;

  PublicNote({
    required this.id,
    required this.title,
    required this.content,
    required this.subjectId,
  });

  factory PublicNote.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PublicNote(
      id: doc.id,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      subjectId: data['subjectId'] ?? '',
    );
  }
}
