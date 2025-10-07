import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../models/subject_model.dart';
import '../../../services/firebase_data_service.dart';

class SubjectsScreen extends StatefulWidget {
  final Map<String, String> seriesData;
  const SubjectsScreen({super.key, required this.seriesData});

  @override
  State<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends State<SubjectsScreen> {
  final FirebaseDataService dataService = FirebaseDataService();
  late Future<List<Subject>> _subjectsFuture;
  late String seriesName;

  // NativeAd related variables and functions have been removed.

  @override
  void initState() {
    super.initState();
    final seriesId = widget.seriesData['seriesId']!;
    seriesName = widget.seriesData['seriesName']!;
    _subjectsFuture = dataService.getSubjects(seriesId);
    // _loadNativeAd() call removed.
  }

  // _loadNativeAd() and dispose() methods for the ad have been removed.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(seriesName),
      ),
      body: FutureBuilder<List<Subject>>(
        future: _subjectsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No subjects found for this series.'));
          }

          final subjects = snapshot.data!;
          // The logic to insert the ad into the list has been removed.
          
          return GridView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: subjects.length, // Directly use the subjects list length.
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.8,
            ),
            itemBuilder: (context, index) {
              final subject = subjects[index];
              // The check for NativeAd is no longer needed.
              return _buildSubjectCard(context, subject, seriesName);
            },
          );
        },
      ),
    );
  }
  
  Widget _buildSubjectCard(BuildContext context, Subject subject, String seriesName) {
    return GestureDetector(
      onTap: () {
        final subjectData = {
          'subjectId': subject.id,
          'subjectName': subject.name,
        };
        context.push('/topics', extra: subjectData);
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      seriesName.toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      subject.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Text(
                      'Topic wise | Major Test | Full Test',
                      style: Theme.of(context).textTheme.bodySmall,
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
