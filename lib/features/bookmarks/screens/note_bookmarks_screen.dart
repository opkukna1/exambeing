// lib/features/bookmarks/screens/note_bookmarks_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:exambeing/helpers/database_helper.dart';
import 'package:exambeing/models/public_note_model.dart';

class NoteBookmarksScreen extends StatefulWidget {
  const NoteBookmarksScreen({super.key});

  @override
  // ✅ FIX: Removed underscore to make state class public
  NoteBookmarksScreenState createState() => NoteBookmarksScreenState();
}

// ✅ FIX: Removed underscore from class name
class NoteBookmarksScreenState extends State<NoteBookmarksScreen> {
  final dbHelper = DatabaseHelper.instance;
  late Future<List<PublicNote>> _bookmarksFuture;

  @override
  void initState() {
    super.initState();
    _bookmarksFuture = dbHelper.getAllBookmarkedNotes(); 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[50],
      appBar: AppBar(
        title: const Text('Bookmarked Notes'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: FutureBuilder<List<PublicNote>>(
        future: _bookmarksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No bookmarked notes found.',
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          final bookmarks = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(12.0),
            itemCount: bookmarks.length,
            itemBuilder: (context, index) {
              final bookmark = bookmarks[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFF3E0),
                    child: Icon(Icons.bookmark, color: Colors.orange),
                  ),
                  title: Text(bookmark.title, style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text('Content: ${bookmark.content.substring(0, 20)}...'),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                  onTap: () {
                    context.push('/bookmark-note-detail', extra: bookmark);
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
