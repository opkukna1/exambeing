import 'package:flutter/material.dart';
import 'package:exambeing/models/public_note_model.dart';
import 'package:exambeing/models/note_content_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// If you want to allow saving personal notes related to this public note,
// you can import AddEditNoteScreen here, but for now, let's keep it simple.

class NoteDetailScreen extends StatefulWidget {
  final PublicNote note;
  
  const NoteDetailScreen({super.key, required this.note});

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  bool _isLoading = true;
  String _content = '';

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    try {
      // Fetch content from 'noteContent' collection using the note ID
      final doc = await FirebaseFirestore.instance
          .collection('NoteContent')
          .doc(widget.note.id)
          .get();

      if (doc.exists) {
        final noteContent = NoteContent.fromFirestore(doc);
        setState(() {
          _content = noteContent.content;
          _isLoading = false;
        });
      } else {
        setState(() {
          _content = 'Content not available.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _content = 'Error loading content: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note.subSubjectName),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.note.title,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Published: ${widget.note.timestamp.toDate().toString().split(' ')[0]}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const Divider(height: 30),
                  Text(
                    _content,
                    style: const TextStyle(fontSize: 16, height: 1.6),
                  ),
                ],
              ),
            ),
    );
  }
}
