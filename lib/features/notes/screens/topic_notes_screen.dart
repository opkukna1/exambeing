import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:exambeing/models/public_note_model.dart'; // Apka Note Model
import 'package:exambeing/models/note_sub_subject_model.dart'; // Apka SubSubject Model
import 'package:exambeing/features/notes/screens/note_detail_screen.dart'; // Detail Screen

class TopicNotesScreen extends StatelessWidget {
  final NoteSubSubject subSubject; // Pichli screen se aaya data

  const TopicNotesScreen({super.key, required this.subSubject});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(subSubject.name), // e.g. "Rajasthan Itihas"
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('public_notes') // ✅ Collection ka naam check karein
            // ✅ FILTER: Hum sirf wahi notes layenge jinki subSubjectId match karegi
            .where('subSubjectId', isEqualTo: subSubject.id)
            .snapshots(),
        builder: (context, snapshot) {
          // 1. Error Handling
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          // 2. Loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 3. Empty Check
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.note_alt_outlined, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    "No notes found in '${subSubject.name}'",
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  // Debugging ke liye ID dikha rahe hain (Baad me hata dena)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text("Looking for subSubjectId:\n${subSubject.id}", 
                      textAlign: TextAlign.center, 
                      style: const TextStyle(fontSize: 10, color: Colors.red)),
                  )
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          // 4. Data List
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              // Data ko Model me convert karein
              PublicNote note = PublicNote.fromFirestore(docs[index]);

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: Colors.deepPurple.withOpacity(0.1),
                    child: const Icon(Icons.description, color: Colors.deepPurple),
                  ),
                  title: Text(
                    note.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    // ✅ Detail Screen par bhejein
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
