import 'package:cloud_firestore/cloud_firestore.dart';

class Topic {
  final String id;
  final String name;
  final String subjectId;
  final int rank; // ✅ 1. Naya Field (Ranking ke liye)

  Topic({
    required this.id,
    required this.name,
    required this.subjectId,
    this.rank = 9999, // ✅ 2. Default value (Taaki purana code crash na ho)
  });

  factory Topic.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Topic(
      id: doc.id,
      name: data['name'] ?? '',
      subjectId: data['subjectId'] ?? '',
      rank: data['rank'] ?? 9999, // ✅ 3. Firestore se Rank read karega
    );
  }
}
