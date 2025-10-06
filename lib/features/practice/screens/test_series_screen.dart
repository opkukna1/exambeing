import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../models/test_series_model.dart'; // Model file import
import '../../../services/firebase_data_service.dart'; // Service file import

class TestSeriesScreen extends StatefulWidget {
  const TestSeriesScreen({super.key});

  @override
  State<TestSeriesScreen> createState() => _TestSeriesScreenState();
}

class _TestSeriesScreenState extends State<TestSeriesScreen> {
  final FirebaseDataService _dataService = FirebaseDataService();
  late Future<List<TestSeries>> _testSeriesFuture;

  @override
  void initState() {
    super.initState();
    _testSeriesFuture = _dataService.getTestSeries();
  }

  @override
  Widget build(BuildContext context) {
    // This screen does not need its own Scaffold because it's shown inside the MainScreen
    return FutureBuilder<List<TestSeries>>(
      future: _testSeriesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No test series found.'));
        }

        final testSeriesList = snapshot.data!;
        
        return GridView.builder(
          padding: const EdgeInsets.all(16.0),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, // A row with two items
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.85, // Adjust the card size
          ),
          itemCount: testSeriesList.length,
          itemBuilder: (context, index) {
            final testSeries = testSeriesList[index];
            return _buildSeriesCard(context, testSeries);
          },
        );
      },
    );
  }

  // A helper widget to build the card UI, similar to the "Testline" app
  Widget _buildSeriesCard(BuildContext context, TestSeries testSeries) {
    return GestureDetector(
      onTap: () {
        final seriesData = {
          'seriesId': testSeries.id,
          'seriesName': testSeries.name,
        };
        // Navigate to the subjects screen, passing the ID of the selected series
        context.push('/subjects', extra: seriesData);
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      testSeries.name, 
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      )
                    ),
                    const SizedBox(height: 4),
                    Text(
                      testSeries.description, 
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant
                      )
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
              color: Colors.black.withOpacity(0.05),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Start", style: TextStyle(fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
