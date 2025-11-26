import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:exambeing/models/note_sub_subject_model.dart';
import 'package:exambeing/features/notes/screens/topic_notes_screen.dart';

class NotesTopicsScreen extends StatefulWidget {
  final Map<String, dynamic> subjectData;
  const NotesTopicsScreen({super.key, required this.subjectData});

  @override
  _NotesTopicsScreenState createState() => _NotesTopicsScreenState();
}

class _NotesTopicsScreenState extends State<NotesTopicsScreen> {
  @override
  Widget build(BuildContext context) {
    String subjectName = widget.subjectData['subject'] ?? '';

    return Scaffold(
      backgroundColor: Colors.blueGrey[50],
      appBar: AppBar(title: Text(subjectName)),
      // ✅ CHANGE: Collection 'NoteSubSubjects'
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('NoteSubSubjects')
            .where('subjectName', isEqualTo: subjectName)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No sub-subjects found."));
          }

          final topicDocs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12.0),
            itemCount: topicDocs.length,
            itemBuilder: (context, index) {
              NoteSubSubject topic = NoteSubSubject.fromFirestore(topicDocs[index]);

              return Card(
                margin: const EdgeInsets.all(6),
                child: ListTile(
                  leading: const Icon(Icons.folder_open, color: Colors.deepPurple),
                  title: Text(topic.name), // e.g., Rajasthan Itihas
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TopicNotesScreen(subSubject: topic),
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
