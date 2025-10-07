import 'package:flutter/material.dart';
import 'package:exambeing/services/firebase_data_service.dart'; // ✅ FIX: Using the correct service

// ✅ FIX: Converted to a StatefulWidget to load data from Firebase
class NotesListScreen extends StatefulWidget {
  final Map<String, dynamic> subject;
  const NotesListScreen({super.key, required this.subject});

  @override
  State<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends State<NotesListScreen> {
  final FirebaseDataService _dataService = FirebaseDataService();
  late Future<List<Map<String, dynamic>>> _topicsFuture;

  @override
  void initState() {
    super.initState();
    // ✅ FIX: Fetching data from Firebase when the screen loads
    _topicsFuture = _dataService.getTopics(widget.subject['name'] as String);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.subject['name']} Notes'),
      ),
      // ✅ FIX: Using a FutureBuilder to display the data after it loads
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _topicsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No topics found for this subject.'));
          }

          final relevantTopics = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(12.0),
            itemCount: relevantTopics.length,
            itemBuilder: (context, index) {
              final topic = relevantTopics[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0, top: 8.0, bottom: 8.0),
                        child: Text(
                          topic['name'] as String,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red),
                        title: const Text('Chapter Notes (Hindi)'),
                        trailing: ElevatedButton(onPressed: () {}, child: const Text('View')),
                      ),
                      ListTile(
                        leading: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red),
                        title: const Text('Chapter Notes (English)'),
                        trailing: ElevatedButton(onPressed: () {}, child: const Text('View')),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
