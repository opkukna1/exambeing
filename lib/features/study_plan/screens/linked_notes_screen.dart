import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ⚠️ IMPORTANT: Apni NotesOnlineViewScreen wali file ka sahi path yahan import karein
// Example: import 'package:exambeing/features/notes/screens/notes_online_view_screen.dart';
// Abhi main maan ke chal raha hu ki aap path fix kar lenge. 
// Agar file same folder me nahi hai to error aayega, use fix kar lena.

import 'package:exambeing/features/notes/screens/notes_online_view_screen.dart'; 

class LinkedNotesScreen extends StatelessWidget {
  final String weekTitle;
  final List<dynamic> linkedTopics; // Names of topics (e.g. "Indus Valley")

  const LinkedNotesScreen({super.key, required this.weekTitle, required this.linkedTopics});

  @override
  Widget build(BuildContext context) {
    if (linkedTopics.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(weekTitle)),
        body: const Center(child: Text("No topics assigned for this week.")),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(title: Text(weekTitle), elevation: 0),
      body: StreamBuilder<QuerySnapshot>(
        // 🔥 QUERY: Hum 'displayName' dhoondhenge jo linkedTopics se match kare
        stream: FirebaseFirestore.instance
            .collection('notes_content')
            .where('displayName', whereIn: linkedTopics) 
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   const Icon(Icons.library_books_outlined, size: 50, color: Colors.grey),
                   const SizedBox(height: 10),
                   Padding(
                     padding: const EdgeInsets.all(16.0),
                     child: Text(
                       "Notes for these topics are not uploaded yet:\n\n${linkedTopics.join(", ")}", 
                       textAlign: TextAlign.center,
                       style: const TextStyle(color: Colors.grey),
                     ),
                   ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;

              // Naam nikalo (DisplayName ya TopicName)
              String title = data['displayName'] ?? "Untitled Note";

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: Colors.deepPurple.shade50,
                    child: const Icon(Icons.article, color: Colors.deepPurple),
                  ),
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text("Tap to read"),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                  onTap: () {
                    // ✅ USER KO PUCHO: Language aur Mode kya chahiye?
                    _showOptionsAndOpenNote(context, data);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  // 👇 Dialog to select Language & Mode before opening
  void _showOptionsAndOpenNote(BuildContext context, Map<String, dynamic> noteData) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Select Preferences", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              
              // 1. Language Options
              const Text("Language:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildOptionBtn(ctx, "Hindi", noteData),
                  const SizedBox(width: 10),
                  _buildOptionBtn(ctx, "English", noteData),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionBtn(BuildContext context, String lang, Map<String, dynamic> noteData) {
    return Expanded(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple.shade50,
          foregroundColor: Colors.deepPurple,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onPressed: () {
          // Close BottomSheet
          Navigator.pop(context);
          
          // Mode select karne ka option bhi de sakte hain, par abhi simplify karke 'Detailed' kholte hain
          // Aap chahein to ek aur Dialog laga sakte hain Mode ke liye.
          
          _openViewer(context, noteData, lang, "Detailed");
        },
        child: Text(lang),
      ),
    );
  }

  void _openViewer(BuildContext context, Map<String, dynamic> rawData, String lang, String mode) {
    // Data prepare karein jo NotesOnlineViewScreen ko chahiye
    // Make sure ki rawData me subjId, topicId wagera maujood hain.
    // Agar Firestore document me ye IDs save nahi hain, to ye logic fail ho jayega.
    // Assuming: notes_content documents contain these ID fields internally.
    
    Map<String, dynamic> dataForViewer = {
      'subjId': rawData['subjId'] ?? '',
      'subSubjId': rawData['subSubjId'] ?? '',
      'topicId': rawData['topicId'] ?? '',
      'subTopId': rawData['subTopId'] ?? '',
      'displayName': rawData['displayName'] ?? 'Note',
      'lang': lang,
      'mode': mode,
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NotesOnlineViewScreen(data: dataForViewer),
      ),
    );
  }
}
