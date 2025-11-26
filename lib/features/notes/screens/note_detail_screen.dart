import 'package:flutter/material.dart';
import 'package:exambeing/models/my_note_model.dart'; // Note ka Model
import 'package:exambeing/helpers/database_helper.dart';
import 'package:exambeing/features/notes/screens/add_edit_note_screen.dart';

class NoteDetailViewScreen extends StatefulWidget {
  final int noteId; // Hum ID se note load karenge taaki latest data mile

  const NoteDetailViewScreen({super.key, required this.noteId});

  @override
  State<NoteDetailViewScreen> createState() => _NoteDetailViewScreenState();
}

class _NoteDetailViewScreenState extends State<NoteDetailViewScreen> {
  late Future<MyNote> _noteFuture;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadNote();
  }

  void _loadNote() {
    setState(() {
      _noteFuture = DatabaseHelper.instance.readNote(widget.noteId);
    });
  }

  // Delete karne ka function
  Future<void> _deleteNote() async {
    setState(() => _isLoading = true);
    await DatabaseHelper.instance.delete(widget.noteId);
    if (mounted) {
      Navigator.pop(context); // List screen par wapas jao
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MyNote>(
      future: _noteFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final note = snapshot.data!;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.black),
            actions: [
              // EDIT BUTTON (Pencil)
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.deepPurple),
                tooltip: 'Edit Note',
                onPressed: () async {
                  // Edit screen par jao
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddEditNoteScreen(note: note),
                    ),
                  );
                  _loadNote(); // Wapas aane par naya data load karo
                },
              ),
              // DELETE BUTTON
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Delete Note',
                onPressed: () => showDialog(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text("Delete Note?"),
                    content: const Text("Are you sure you want to delete this note?"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c), 
                        child: const Text("Cancel")
                      ),
                      TextButton(
                        onPressed: () { 
                          Navigator.pop(c); 
                          _deleteNote(); 
                        }, 
                        child: const Text("Delete", style: TextStyle(color: Colors.red))
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    note.title,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Date
                  Text(
                    note.createdAt,
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 20),
                  // Full Content
                  Text(
                    note.content,
                    style: const TextStyle(
                      fontSize: 18,
                      height: 1.6,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
        );
      },
    );
  }
}
