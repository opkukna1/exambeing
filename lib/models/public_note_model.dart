import 'package.cloud_firestore/cloud_firestore.dart';

// Yeh model list (PublicNotesScreen) aur Bookmarks, dono ke liye hai
class PublicNote {
  final String id; // Document ID
  final String title;
  final String subjectId;
  final String subSubjectId; // e.g., "raj_itihas_01"
  final String subSubjectName; // e.g., "Rajasthan Itihas"
  final Timestamp timestamp; // "Latest Notes" ke liye zaroori
  
  // ⬇️===== YEH HAI ASLI FIX (Content ko waapas add kiya) =====⬇️
  final String? content; // Content ab optional (nullable) hai
  // ⬆️=======================================================⬆️

  PublicNote({
    required this.id,
    required this.title,
    required this.subjectId,
    required this.subSubjectId,
    required this.subSubjectName,
    required this.timestamp,
    this.content, // Constructor mein optional banaya
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
      // ⬇️===== YEH HAI ASLI FIX (Content ko read karo) =====⬇️
      // Agar 'content' field hai to use padho, agar nahi hai to null rakho
      content: data['content'] as String?, 
      // ⬆️=================================================⬆️
    );
  }
}
