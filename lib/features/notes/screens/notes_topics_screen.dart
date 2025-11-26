import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:exambeing/helpers/database_helper.dart';
import 'package:exambeing/models/bookmarked_note_model.dart'; // Correct Import
import 'package:exambeing/models/note_sub_subject_model.dart';
import 'package:exambeing/features/notes/screens/topic_notes_screen.dart';

class NotesTopicsScreen extends StatefulWidget {
  final Map<String, dynamic> subjectData;
  // Expected data: {'subject': 'History', 'id': 'subject_doc_id'}

  const NotesTopicsScreen({super.key, required this.subjectData});

  @override
  _NotesTopicsScreenState createState() => _NotesTopicsScreenState();
}

class _NotesTopicsScreenState extends State<NotesTopicsScreen> {
  final dbHelper = DatabaseHelper.instance;
  // ✅ FIX: Use BookmarkedNote type
  List<BookmarkedNote> _bookmarkedPages = [];

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    final allBookmarkedNotes = await dbHelper.getAllBookmarkedNotes();
    // Note: You might need to check if your BookmarkedNote model actually has 'subjectName'.
    // If it's saved as 'subjectId', you might need to filter by that or just show all for now.
    // Assuming BookmarkedNote has a 'subjectName' field or similiar you saved.
    // If not, remove the filter or update the model.
    
    // Safe filter:
    final subjectName = widget.subjectData['subject'];
    final filteredBookmarks = allBookmarkedNotes.where((bookmark) {
      // Check your BookmarkedNote model fields. It usually has subjectId or subSubjectName.
      // If you don't have subjectName in bookmark, you can't filter by it easily here.
      // For now, let's return true to show all, or filter if field exists.
      // return bookmark.subjectName == subjectName; 
      return true; 
    }).toList();

    if (mounted) {
      setState(() {
        _bookmarkedPages = filteredBookmarks;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String subjectName = widget.subjectData['subject'] ?? '';

    return Scaffold(
      backgroundColor: Colors.blueGrey[50],
      appBar: AppBar(
        title: Text(subjectName),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_bookmarkedPages.isNotEmpty) _buildRevisionSection(context),

            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                'All Topics',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('NoteSubSubjects')
                  .where('subjectName', isEqualTo: subjectName)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Center(child: Text("No topics found for this subject.")),
                  );
                }

                final topicDocs = snapshot.data!.docs;

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  itemCount: topicDocs.length,
                  itemBuilder: (context, index) {
                    NoteSubSubject topic = NoteSubSubject.fromFirestore(topicDocs[index]);

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.deepPurple.withOpacity(0.1),
                          child: const Icon(Icons.article_outlined, color: Colors.deepPurple),
                        ),
                        title: Text(
                          topic.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18, color: Colors.grey),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TopicNotesScreen(subSubject: topic),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 20),
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
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.orange[800]),
          ),
          const SizedBox(height: 8),
          ..._bookmarkedPages.map((bookmark) {
            return Card(
              color: Colors.yellow[50],
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              child: ListTile(
                leading: const Icon(Icons.bookmark, color: Colors.orange),
                title: Text(bookmark.title),
                trailing: const Icon(Icons.open_in_new, size: 20, color: Colors.orange),
                onTap: () {
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
