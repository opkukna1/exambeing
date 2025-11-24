import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class SubjectListScreen extends StatelessWidget {
  final String seriesId;
  final String seriesTitle;

  const SubjectListScreen({
    super.key, 
    required this.seriesId, 
    required this.seriesTitle
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(seriesTitle), // Series ka naam (e.g., RPSC 1st Grade)
      ),
      body: StreamBuilder<QuerySnapshot>(
        // ⚠️ NESTED QUERY: testSeriesHome -> seriesId -> subjects
        stream: FirebaseFirestore.instance
            .collection('testSeriesHome')
            .doc(seriesId)
            .collection('subjects')
            .snapshots(),
        builder: (context, snapshot) {
          // 1. Loading State
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. Empty State
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.library_books_outlined, size: 50, color: Colors.grey),
                  const SizedBox(height: 10),
                  Text(
                    "No subjects found in $seriesTitle.",
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final subjects = snapshot.data!.docs;

          // 3. List View
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: subjects.length,
            itemBuilder: (context, index) {
              final data = subjects[index].data() as Map<String, dynamic>;
              final subjectId = subjects[index].id;
              final title = data['title'] ?? 'Untitled Subject';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.menu_book_rounded, color: Colors.blue),
                  ),
                  title: Text(
                    title, 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                  ),
                  subtitle: const Text("Tap to view tests"),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  onTap: () {
                    // ✅ Go to Test List
                    // Hum SeriesID aur SubjectID dono pass kar rahe hain
                    // taaki agli screen nested path dhundh sake.
                    context.push('/test-list', extra: {
                      'seriesId': seriesId,
                      'subjectId': subjectId,
                      'subjectTitle': title,
                    });
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
