// lib/features/notes/screens/notes_topics_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../helpers/database_helper.dart'; // FIX: इम्पोर्ट जोड़ा गया

class NotesTopicsScreen extends StatefulWidget {
  final Map<String, dynamic> subjectData;
  const NotesTopicsScreen({super.key, required this.subjectData});

  @override
  _NotesTopicsScreenState createState() => _NotesTopicsScreenState();
}

class _NotesTopicsScreenState extends State<NotesTopicsScreen> {
  final dbHelper = DatabaseHelper.instance;
  List<Bookmark> _bookmarkedPages = [];

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    final List<String> topicFilePaths = (widget.subjectData['topics'] as List<dynamic>)
      .map((topic) => topic['filePath'] as String)
      .toList();
      
    final bookmarks = await dbHelper.getBookmarksForSubject(topicFilePaths);
    setState(() {
      _bookmarkedPages = bookmarks;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<dynamic> topics = widget.subjectData['topics'];
    return Scaffold(
      backgroundColor: Colors.blueGrey[50],
      appBar: AppBar(
        title: Text(widget.subjectData['subject']),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_bookmarkedPages.isNotEmpty)
              _buildRevisionSection(context),

            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                'All Topics',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              itemCount: topics.length,
              itemBuilder: (context, index) {
                final topic = topics[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 6.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.deepPurple.withOpacity(0.1),
                      child: const Icon(Icons.article_outlined, color: Colors.deepPurple),
                    ),
                    title: Text(topic['topicName'], style: const TextStyle(fontWeight: FontWeight.w500)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                    onTap: () => context.push('/note_viewer', extra: topic),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevisionSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Revision (Bookmarked Pages)',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ..._bookmarkedPages.map((bookmark) {
            return Card(
              color: Colors.yellow[100],
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              child: ListTile(
                leading: const Icon(Icons.bookmark, color: Colors.orange),
                title: Text(bookmark.topicName),
                subtitle: Text('Page ${bookmark.pageNumber}'),
                onTap: () {
                  context.push('/note_viewer', extra: {
                    'topicName': bookmark.topicName,
                    'filePath': bookmark.noteFilePath,
                    'initialPage': bookmark.pageNumber,
                  },);
                },
              ),
            );
          }).toList(),
          const Divider(height: 24),
        ],
      ),
    );
  }
}
