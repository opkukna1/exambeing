import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ Firebase import
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
      // ✅ StreamBuilder lagaya hai jo seedha Firebase se data layega
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('subjects').snapshots(),
        builder: (context, snapshot) {
          // 1. Loading State
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. Error State
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          // 3. Empty State
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No subjects found."));
          }

          // 4. Data List
          final subjectsDocs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12.0),
            itemCount: subjectsDocs.length,
            itemBuilder: (context, index) {
              var data = subjectsDocs[index].data() as Map<String, dynamic>;
              
              // Firebase field ka naam 'name' hona chahiye (e.g., "History")
              String subjectName = data['name'] ?? 'Unknown Subject'; 
              String docId = subjectsDocs[index].id;

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange.withOpacity(0.1),
                    child: const Icon(Icons.library_books, color: Colors.orange),
                  ),
                  title: Text(
                    subjectName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18, color: Colors.grey),
                  onTap: () {
                    // ✅ Data pass kar rahe hain agli screen (NotesTopicsScreen) ke liye
                    // Hum 'subject' key bhej rahe hain kyunki agli screen wahi expect kar rahi hai
                    context.push('/notes_topics', extra: {
                      'subject': subjectName,
                      'id': docId, // Doc ID bhi bhej dete hain agar future me zarurat pade
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
