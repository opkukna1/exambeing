import 'package:cloud_firestore/cloud_firestore.dart';

class Offer {
  final String id;
  final String title;
  final String description;
  final String price;
  final String imageUrl;

  Offer({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.imageUrl,
  });

  factory Offer.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Offer(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      price: data['price'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
    );
  }
}
