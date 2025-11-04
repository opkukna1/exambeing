import 'package:cloud_firestore/cloud_firestore.dart';

// Yeh model Main Subjects (Tabs) ke liye hai
// Jaise: "Itihas", "Bhugol"
class NoteSubject {
  final String id;
  final String name;

  NoteSubject({required this.id, required this.name});

  factory NoteSubject.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NoteSubject(
      id: doc.id,
      name: data['name'] ?? '',
    );
  }
}
