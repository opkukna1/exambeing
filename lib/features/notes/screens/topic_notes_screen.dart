import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:exambeing/models/public_note_model.dart';
import 'package:exambeing/models/note_sub_subject_model.dart';
import 'package:exambeing/features/notes/screens/note_detail_screen.dart';

class TopicNotesScreen extends StatelessWidget {
  final NoteSubSubject subSubject;

  const TopicNotesScreen({super.key, required this.subSubject});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(subSubject.name)),
      // ✅ CHANGE: Collection 'PublicNotes'
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('PublicNotes')
            .where('subSubjectName', isEqualTo: subSubject.name)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No notes found here."));
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              PublicNote note = PublicNote.fromFirestore(docs[index]);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.description, color: Colors.blue),
                  title: Text(note.title),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NoteDetailScreen(note: note),
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
