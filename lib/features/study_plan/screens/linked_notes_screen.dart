import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Note Detail Import karein
import 'package:exambeing/features/notes/screens/note_detail_screen.dart';
import 'package:exambeing/models/public_note_model.dart';

class LinkedNotesScreen extends StatelessWidget {
  final String weekTitle;
  final List<dynamic> linkedTopics; // List jo Admin ne select ki thi

  const LinkedNotesScreen({super.key, required this.weekTitle, required this.linkedTopics});

  @override
  Widget build(BuildContext context) {
    // Agar koi topic nahi hai
    if (linkedTopics.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(weekTitle)),
        body: const Center(child: Text("No topics assigned for this week.")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(weekTitle)),
      body: StreamBuilder<QuerySnapshot>(
        // 🔥 MAGIC QUERY: "whereIn" sirf wahi notes layega jo list me hain
        // NOTE: Firestore limit hai ki 'whereIn' me max 10 items ho sakte hain.
        // Agar topics 10 se zyada hain, to logic badalna padega (Client side filtering).
        // Abhi ke liye Maan ke chalte hain 10 se kam topics honge per week.
        stream: FirebaseFirestore.instance
            .collection('notes_content')
            .where('topicName', whereIn: linkedTopics) 
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          if (snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   const Icon(Icons.note_alt_outlined, size: 50, color: Colors.grey),
                   const SizedBox(height: 10),
                   Text("Notes for '${linkedTopics.join(", ")}' \nare not uploaded yet.", textAlign: TextAlign.center),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              PublicNote note = PublicNote.fromMap(doc.data() as Map<String, dynamic>, doc.id);

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const CircleAvatar(backgroundColor: Colors.deepPurple, child: Icon(Icons.book, color: Colors.white)),
                  title: Text(note.title ?? "No Title", style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(note.topicName ?? ""),
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: () {
                    // Note Open Karein
                    Navigator.push(context, MaterialPageRoute(builder: (c) => NoteDetailScreen(note: note)));
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
