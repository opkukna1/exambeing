// lib/features/bookmarks/screens/note_bookmarks_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../helpers/database_helper.dart'; // FIX: इम्पोर्ट जोड़ा गया

class NoteBookmarksScreen extends StatefulWidget {
  const NoteBookmarksScreen({super.key});

  @override
  _NoteBookmarksScreenState createState() => _NoteBookmarksScreenState();
}

class _NoteBookmarksScreenState extends State<NoteBookmarksScreen> {
  final dbHelper = DatabaseHelper.instance;
  late Future<List<Bookmark>> _bookmarksFuture;

  @override
  void initState() {
    super.initState();
    _bookmarksFuture = dbHelper.getAllBookmarks();
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
      body: FutureBuilder<List<Bookmark>>(
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
                  title: Text(bookmark.topicName, style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text('Page ${bookmark.pageNumber}'),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                  onTap: () {
                    context.push('/note_viewer', extra: {
                      'topicName': bookmark.topicName,
                      'filePath': bookmark.noteFilePath,
                      'initialPage': bookmark.pageNumber,
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
