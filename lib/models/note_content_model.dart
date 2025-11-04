import 'package:cloud_firestore/cloud_firestore.dart';

// Yeh model NoteDetailScreen par poora content dikhane ke liye hai
class NoteContent {
  final String id; // Document ID
  final String content; // Poora note

  NoteContent({
    required this.id,
    required this.content,
  });

  factory NoteContent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NoteContent(
      id: doc.id,
      content: data['content'] ?? 'No content found.',
    );
  }
}
