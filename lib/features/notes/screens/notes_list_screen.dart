import 'package:flutter/material.dart';
import 'package:exambeing/services/firebase_data_service.dart';
import 'package:exambeing/models/topic_model.dart';
import 'package:exambeing/features/notes/screens/topic_notes_screen.dart'; // ✅ Nayi screen import karein

class NotesListScreen extends StatefulWidget {
  final Map<String, dynamic> subject;
  const NotesListScreen({super.key, required this.subject});

  @override
  State<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends State<NotesListScreen> {
  final FirebaseDataService _dataService = FirebaseDataService();
  late Future<List<Topic>> _topicsFuture;

  @override
  void initState() {
    super.initState();
    // Subject ke naam se Topics (Sub-subjects) laayenge
    _topicsFuture = _dataService.getTopics(widget.subject['name'] as String);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('${widget.subject['name']} Topics'),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      body: FutureBuilder<List<Topic>>(
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
              
              // ✅ Yahan se Hardcoded Notes hata diye gaye hain
              // Ab bas Topic ka naam dikhega, click karne par notes aayenge
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    child: const Icon(Icons.folder_open, color: Colors.blue),
                  ),
                  title: Text(
                    topic.name, // e.g., "Rajasthan ka Itihas"
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  onTap: () {
                    // ✅ Click karne par "TopicNotesScreen" khulega
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TopicNotesScreen(
                          topicName: topic.name, // Topic ka naam pass kar rahe hain
                        ),
                      ),
                    );
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
