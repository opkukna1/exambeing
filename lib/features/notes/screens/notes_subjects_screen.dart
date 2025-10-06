// lib/features/notes/screens/notes_subjects_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'package:go_router/go_router.dart';

class NotesSubjectsScreen extends StatefulWidget {
  const NotesSubjectsScreen({super.key});

  @override
  _NotesSubjectsScreenState createState() => _NotesSubjectsScreenState();
}

class _NotesSubjectsScreenState extends State<NotesSubjectsScreen> {
  List<dynamic> _notesData = [];

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    try {
      final String response = await rootBundle.loadString('assets/notes_manifest.json');
      final data = await json.decode(response);
      setState(() {
        _notesData = data;
      });
    } catch (e) {
      // Handle error, maybe show a message
      print("Error loading notes manifest: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[50],
      appBar: AppBar(
        title: const Text('Notes - Subjects'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: _notesData.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(12.0),
              itemCount: _notesData.length,
              itemBuilder: (context, index) {
                final subject = _notesData[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 6.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange.withOpacity(0.1),
                      child: const Icon(Icons.library_books, color: Colors.orange),
                    ),
                    title: Text(subject['subject'], style: const TextStyle(fontWeight: FontWeight.w500)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                    onTap: () => context.push('/notes_topics', extra: subject),
                  ),
                );
              },
            ),
    );
  }
}
