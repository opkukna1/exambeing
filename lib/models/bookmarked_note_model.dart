import 'package:cloud_firestore/cloud_firestore.dart';

// Yeh model SIRF local database (SQFlite) mein save kiye gaye
// bookmarked notes ke liye hai.
class BookmarkedNote {
  final String id; // Firebase Document ID
  final String title;
  final String content; // ✅ Yahaan content hamesha non-optional hai
  final String subjectId;
  final String subSubjectId;
  final String subSubjectName;
  final Timestamp timestamp;

  BookmarkedNote({
    required this.id,
    required this.title,
    required this.content,
    required this.subjectId,
    required this.subSubjectId,
    required this.subSubjectName,
    required this.timestamp,
  });

  // Database (map) se vaapas laane ke liye
  factory BookmarkedNote.fromDbMap(Map<String, dynamic> json) {
    return BookmarkedNote(
      id: json['noteId'] as String,
      title: json['title'] as String,
      content: json['content'] as String? ?? '', // Agar DB mein null ho to empty string
      subjectId: json['subjectId'] as String,
      subSubjectId: json['subSubjectId'] as String,
      subSubjectName: json['subSubjectName'] as String,
      timestamp: Timestamp.fromDate(DateTime.parse(json['timestamp'] as String)),
    );
  }
}
