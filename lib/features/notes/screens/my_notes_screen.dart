import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

  // Function to refresh the notes from the database
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
            return const Center(
              child: Text(
                'You have no notes yet.\nTap the + button to add one!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          final notes = snapshot.data!;
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
          // Navigate to the Add/Edit screen and refresh when we come back
          final result = await context.push<bool>('/add-edit-note');
          if (result == true) {
            _refreshNotes();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildNoteCard(MyNote note) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () async {
                      final result = await context.push<bool>('/add-edit-note', extra: note);
                      if (result == true) {
                        _refreshNotes();
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () async {
                      await DatabaseHelper.instance.delete(note.id!);
                      _refreshNotes();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Note deleted')),
                      );
                    },
                  ),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    note.content,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 18, height: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Created: ${note.createdAt}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
