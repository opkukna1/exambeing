import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class NotesSubjectsScreen extends StatefulWidget {
  const NotesSubjectsScreen({super.key});

  @override
  _NotesSubjectsScreenState createState() => _NotesSubjectsScreenState();
}

class _NotesSubjectsScreenState extends State<NotesSubjectsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[50],
      appBar: AppBar(
        title: const Text('Notes - Subjects'),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      // ✅ CHANGE: Collection 'NoteSubjects' (Main Subject)
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('NoteSubjects').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No subjects found in 'NoteSubjects'."));
          }

          final subjectsDocs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12.0),
            itemCount: subjectsDocs.length,
            itemBuilder: (context, index) {
              var data = subjectsDocs[index].data() as Map<String, dynamic>;
              String subjectName = data['name'] ?? 'Unknown';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6.0),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.book, color: Colors.orange)),
                  title: Text(subjectName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // ✅ Agli screen par 'subject' bhej rahe hain
                    context.push('/notes_topics', extra: {'subject': subjectName});
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
