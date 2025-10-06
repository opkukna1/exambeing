// FIX: 'package.' has been removed from the import statement
import 'package:cloud_firestore/cloud_firestore.dart';

class TestSeries {
  final String id;
  final String name;
  final String description;

  TestSeries({
    required this.id,
    required this.name,
    required this.description,
  });

  // This factory constructor converts data from Firebase into a TestSeries object
  factory TestSeries.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return TestSeries(
      id: doc.id, // Takes the unique ID of the document
      name: data['name'] ?? '', // Takes the value of the 'name' field
      description: data['description'] ?? '', // Takes the value of the 'description' field
    );
  }
}
