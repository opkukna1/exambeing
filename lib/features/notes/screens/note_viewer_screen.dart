import 'package:flutter/material.dart';
import 'package:exambeing/models/my_note_model.dart'; 
import 'package:exambeing/helpers/database_helper.dart';
import 'package:exambeing/features/notes/screens/add_edit_note_screen.dart';

class NoteDetailViewScreen extends StatefulWidget {
  final int noteId;

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

  Future<void> _deleteNote() async {
    setState(() => _isLoading = true);
    await DatabaseHelper.instance.delete(widget.noteId);
    if (mounted) {
      Navigator.pop(context); 
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
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.deepPurple),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddEditNoteScreen(note: note),
                    ),
                  );
                  _loadNote(); 
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => showDialog(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text("Delete Note?"),
                    content: const Text("This cannot be undone."),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
                      TextButton(onPressed: () { Navigator.pop(c); _deleteNote(); }, child: const Text("Delete", style: TextStyle(color: Colors.red))),
                    ],
                  ),
                ),
              ),
            ],
          ),
          body: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.title,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    note.createdAt,
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                  const Divider(height: 30, thickness: 1),
                  Text(
                    note.content,
                    style: const TextStyle(fontSize: 18, height: 1.6, color: Colors.black87),
                  ),
                ],
              ),
            ),
        );
      },
    );
  }
}
