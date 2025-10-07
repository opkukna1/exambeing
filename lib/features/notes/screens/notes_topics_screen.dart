import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:exambeing/helpers/database_helper.dart';
import 'package:exambeing/models/public_note_model.dart'; // ✅ FIX: Imported the correct model

class NotesTopicsScreen extends StatefulWidget {
  final Map<String, dynamic> subjectData;
  const NotesTopicsScreen({super.key, required this.subjectData});

  @override
  _NotesTopicsScreenState createState() => _NotesTopicsScreenState();
}

class _NotesTopicsScreenState extends State<NotesTopicsScreen> {
  final dbHelper = DatabaseHelper.instance;
  // ✅ FIX: Changed type to PublicNote
  List<PublicNote> _bookmarkedPages = []; 

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  // ✅ FIX: Rewrote this method to use the correct database call and filter the results
  Future<void> _loadBookmarks() async {
    final allBookmarkedNotes = await dbHelper.getAllBookmarkedNotes();
    final subjectId = widget.subjectData['id'];

    // Filter the bookmarks to only show ones relevant to the current subject
    final filteredBookmarks = allBookmarkedNotes.where((bookmark) {
      return bookmark.subjectId == subjectId;
    }).toList();
    
    if (mounted) {
      setState(() {
        _bookmarkedPages = filteredBookmarks;
      });
    }
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
          // ✅ FIX: Updated this section to use the PublicNote model correctly
          ..._bookmarkedPages.map((bookmark) {
            return Card(
              color: Colors.yellow[100],
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              child: ListTile(
                leading: const Icon(Icons.bookmark, color: Colors.orange),
                title: Text(bookmark.title),
                // The PublicNote model does not have a page number, so the subtitle is removed.
                onTap: () {
                  // Navigate to the detail screen, passing the whole bookmark object.
                  context.push('/bookmark-note-detail', extra: bookmark);
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
