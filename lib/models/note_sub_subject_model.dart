import 'package:cloud_firestore/cloud_firestore.dart';

// Yeh model Sub-Subjects (Sub-Tabs) ke liye hai
// Jaise: "Rajasthan Itihas", "Bharatiya Itihas"
class NoteSubSubject {
  final String id;
  final String name;
  final String mainSubjectId; // Taaki humein pata ho yeh 'Itihas' ka hai ya 'Bhugol' ka

  NoteSubSubject({
    required this.id,
    required this.name,
    required this.mainSubjectId,
  });

  factory NoteSubSubject.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NoteSubSubject(
      id: doc.id,
      name: data['name'] ?? '',
      mainSubjectId: data['mainSubjectId'] ?? '',
    );
  }
}
