import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ YEH HAI ASLI FIX

class PublicNote {
  final String id;
  final String title;
  final String subjectId;
  final String subSubjectId;
  final String subSubjectName;
  final Timestamp timestamp;
  
  // Content ab optional (nullable) hai
  final String? content; 

  PublicNote({
    required this.id,
    required this.title,
    required this.subjectId,
    required this.subSubjectId,
    required this.subSubjectName,
    required this.timestamp,
    this.content, // Constructor mein optional
  });

  factory PublicNote.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PublicNote(
      id: doc.id,
      title: data['title'] ?? '',
      subjectId: data['subjectId'] ?? '',
      subSubjectId: data['subSubjectId'] ?? '',
      subSubjectName: data['subSubjectName'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      // Agar 'content' field hai to use padho, agar nahi hai to null rakho
      content: data['content'] as String?, 
    );
  }
}
