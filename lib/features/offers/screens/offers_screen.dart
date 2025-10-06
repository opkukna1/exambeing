import 'package:flutter/material.dart';
import '../../../models/offer_model.dart';
import '../../../services/firebase_data_service.dart';

class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key});

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  final FirebaseDataService _dataService = FirebaseDataService();
  late Future<List<Offer>> _offersFuture;

  @override
  void initState() {
    super.initState();
    _offersFuture = _dataService.getOffers();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Offer>>(
      future: _offersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No offers available right now.'));
        }

        final offers = snapshot.data!;
        
        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: offers.length,
          itemBuilder: (context, index) {
            final offer = offers[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 16.0),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image Placeholder
                  Container(
                    height: 150,
                    width: double.infinity,
                    color: Colors.grey.shade300,
                    child: offer.imageUrl.isNotEmpty
                        ? Image.network(offer.imageUrl, fit: BoxFit.cover)
                        : const Center(child: Icon(Icons.image_not_supported)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          offer.title,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (offer.description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(offer.description, style: Theme.of(context).textTheme.bodyMedium),
                        ],
                        if (offer.price.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Chip(
                            label: Text(
                              offer.price,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                          )
                        ]
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
