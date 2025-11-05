import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill; // Quill import
import 'dart:convert'; // JSON decode ke liye
import '../../../helpers/database_helper.dart';

class MyNotesScreen extends StatefulWidget {
  const MyNotesScreen({super.key});

  @override
  State<MyNotesScreen> createState() => _MyNotesScreenState();
}

class _MyNotesScreenState extends State<MyNotesScreen> {
  late Future<List<MyNote>> _notesFuture;

  @override
  void initState() {
    super.initState();
    _refreshNotes();
  }

  void _refreshNotes() {
    setState(() {
      _notesFuture = DatabaseHelper.instance.readAllNotes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Notes'),
      ),
      body: FutureBuilder<List<MyNote>>(
        future: _notesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.note_add, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No notes yet.\nTap + to add one!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final notes = snapshot.data!;
          // PageView se better ListView/GridView rehta hai agar notes zyada hon,
          // par tumhare design ke hisab se PageView rakha hai.
          return PageView.builder(
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
              return _buildNoteCard(note);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Naya note add karne ke liye route
          final result = await context.push('/add-edit-note');
          if (result == true) {
            _refreshNotes();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildNoteCard(MyNote note) {
    // Quill controller setup for read-only view
    quill.QuillController? _controller;
    try {
      // Koshish karo JSON ki tarah parse karne ki (agar rich text hai)
      final json = jsonDecode(note.content);
      _controller = quill.QuillController(
        document: quill.Document.fromJson(json),
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true, // Sirf dekhne ke liye
      );
    } catch (e) {
      // Agar plain text hai, toh use convert karo
      _controller = quill.QuillController(
        document: quill.Document()..insert(0, note.content),
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Action Buttons Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Created: ${note.createdAt.split(' ')[0]}', // Sirf date dikhao
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        tooltip: 'Edit Note',
                        onPressed: () async {
                          // Edit ke liye note object pass karo
                          final result = await context.push('/add-edit-note', extra: note);
                          if (result == true) {
                            _refreshNotes();
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'Delete Note',
                        onPressed: () => _confirmDelete(note.id!),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(),
              // Note Content Area (using Quill Editor for rich text display)
              Expanded(
                child: quill.QuillEditor.basic(
                  controller: _controller,
                  // v11.5.0 mein configurations aise pass hoti hain:
                  configurations: const quill.QuillEditorConfigurations(
                    sharedConfigurations: quill.QuillSharedConfigurations(
                      locale: Locale('en'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Delete confirmation dialog
  void _confirmDelete(int noteId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await DatabaseHelper.instance.delete(noteId);
              _refreshNotes();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Note deleted successfully')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
