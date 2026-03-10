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
    return Container(
      color: const Color(0xFFF8F9FE), // Modern off-white background
      child: FutureBuilder<List<TestSeries>>(
        future: _testSeriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF5E35B1)));
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 16),
                  Text('Oops! Something went wrong.', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('${snapshot.error}', style: TextStyle(color: Colors.grey.shade500, fontSize: 12), textAlign: TextAlign.center),
                ],
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.layers_clear_rounded, color: Colors.grey.shade300, size: 80),
                  const SizedBox(height: 16),
                  Text('No test series found.', style: TextStyle(color: Colors.grey.shade500, fontSize: 18, fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }

          final testSeriesList = snapshot.data!;
          
          return GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, 
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.85, // Adjusted for perfect modern card height
            ),
            itemCount: testSeriesList.length,
            itemBuilder: (context, index) {
              final testSeries = testSeriesList[index];
              return _buildSeriesCard(context, testSeries);
            },
          );
        },
      ),
    );
  }

  // Modern UI Card 
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
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade100, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000), // Very soft shadow
              blurRadius: 15,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative Background Circle
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF5E35B1).withOpacity(0.05), // Light purple decorative circle
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9800).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFF9800), size: 24), // Orange accent icon
                  ),
                  const SizedBox(height: 12),
                  
                  // Series Name (Title)
                  Text(
                    testSeries.name,
                    style: const TextStyle(
                      color: Color(0xFF2D3142),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  
                  // Series Description (Subtitle)
                  Expanded(
                    child: Text(
                      testSeries.description,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  
                  // Bottom Action Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Explore", 
                        style: TextStyle(
                          color: Color(0xFF5E35B1), 
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7E57C2), Color(0xFF5E35B1)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                      ),
                    ],
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
