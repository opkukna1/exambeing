import 'package:cloud_firestore/cloud_firestore.dart';

// Yeh model list mein (PublicNotesScreen) dikhane ke liye hai
// Ismein sirf title/details hain, poora content nahi hai
class PublicNote {
  final String id; // Document ID
  final String title;
  final String subjectId;
  final String subSubjectId; // e.g., "raj_itihas_01"
  final String subSubjectName; // e.g., "Rajasthan Itihas"
  final Timestamp timestamp; // "Latest Notes" ke liye zaroori

  PublicNote({
    required this.id,
    required this.title,
    required this.subjectId,
    required this.subSubjectId,
    required this.subSubjectName,
    required this.timestamp,
  });

  factory PublicNote.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PublicNote(
      id: doc.id,
      title: data['title'] ?? '',
      subjectId: data['subjectId'] ?? '',
      subSubjectId: data['subSubjectId'] ?? '',
      subSubjectName: data['subSubjectName'] ?? '', // Hum yeh save karenge taaki UI fast ho
      timestamp: data['timestamp'] ?? Timestamp.now(),
    );
  }
}
