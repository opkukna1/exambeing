import 'package:flutter/material.dart';
import 'package:exambeing/helpers/database_helper.dart';
// Import path sahi karein agar alag ho
import 'package:exambeing/models/my_note_model.dart'; 
import 'package:exambeing/features/notes/screens/add_edit_note_screen.dart';
import 'package:exambeing/features/notes/screens/note_detail_view_screen.dart';

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

  // Database se latest notes lana
  void _refreshNotes() {
    setState(() {
      _notesFuture = DatabaseHelper.instance.readAllNotes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100], // Halka grey background
      appBar: AppBar(
        title: const Text(
          'My Notes',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: FutureBuilder<List<MyNote>>(
        future: _notesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.note_alt_outlined, size: 70, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No notes yet.\nTap + to write something!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final notes = snapshot.data!;

          // Grid View (2 columns) Notes dikhane ke liye
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, 
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.85, // Card ka size adjust karein
            ),
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
              return _buildNoteCard(note);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
        onPressed: () async {
          // Naya note banane ke liye
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddEditNoteScreen()),
          );
          _refreshNotes(); // Wapas aane par list refresh
        },
      ),
    );
  }

  Widget _buildNoteCard(MyNote note) {
    return GestureDetector(
      onTap: () async {
        // Click karne par Detail View khulega
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NoteDetailViewScreen(noteId: note.id!),
          ),
        );
        _refreshNotes();
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                note.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              // Content Preview
              Expanded(
                child: Text(
                  note.content,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Date
              Text(
                note.createdAt,
                style: TextStyle(fontSize: 11, color: Colors.grey[400]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
