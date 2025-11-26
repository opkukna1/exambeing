import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ Firebase ke liye
import 'package:exambeing/helpers/database_helper.dart';
import 'package:exambeing/models/public_note_model.dart';
import 'package:exambeing/features/notes/screens/topic_notes_screen.dart'; // ✅ Agli screen ka import

class NotesTopicsScreen extends StatefulWidget {
  final Map<String, dynamic> subjectData; // e.g. {'subject': 'History'}
  const NotesTopicsScreen({super.key, required this.subjectData});

  @override
  _NotesTopicsScreenState createState() => _NotesTopicsScreenState();
}

class _NotesTopicsScreenState extends State<NotesTopicsScreen> {
  final dbHelper = DatabaseHelper.instance;
  List<PublicNote> _bookmarkedPages = [];

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  // Local Database se bookmarks load karna
  Future<void> _loadBookmarks() async {
    final allBookmarkedNotes = await dbHelper.getAllBookmarkedNotes();
    // Filter: Sirf current subject ke bookmarks dikhayein
    final filteredBookmarks = allBookmarkedNotes.where((bookmark) {
      return bookmark.subjectName == widget.subjectData['subject'];
    }).toList();

    if (mounted) {
      setState(() {
        _bookmarkedPages = filteredBookmarks;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String subjectName = widget.subjectData['subject'] ?? 'Subject';

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
            // 1. Bookmarks Section (Agar koi bookmark hai to dikhega)
            if (_bookmarkedPages.isNotEmpty) _buildRevisionSection(context),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Select a Topic',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.blueGrey[800]),
              ),
            ),

            // 2. Firebase StreamBuilder (Asli Topics yahan se aayenge)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('topics') // ⚠️ Check: Firebase me collection ka naam 'topics' hona chahiye
                  .where('subjectName', isEqualTo: subjectName) // ⚠️ Check: Field name same ho
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('Error loading topics: ${snapshot.error}'),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Center(child: Text("No topics found yet.")),
                  );
                }

                final topicsDocs = snapshot.data!.docs;

                return ListView.builder(
                  shrinkWrap: true, // ScrollView ke andar list ke liye zaroori
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  itemCount: topicsDocs.length,
                  itemBuilder: (context, index) {
                    var data = topicsDocs[index].data() as Map<String, dynamic>;
                    String topicName = data['name'] ?? 'Unnamed Topic'; // Firebase field 'name'

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.deepPurple.withOpacity(0.1),
                          child: const Icon(Icons.article_outlined, color: Colors.deepPurple),
                        ),
                        title: Text(topicName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                        onTap: () {
                          // ✅ Sahi Flow: Topic -> Notes List Screen
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TopicNotesScreen(topicName: topicName),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Bookmarks UI Widget
  Widget _buildRevisionSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Revision (Bookmarks)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.orange[800]),
          ),
          const SizedBox(height: 8),
          ..._bookmarkedPages.map((bookmark) {
            return Card(
              color: Colors.orange[50],
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.orange.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                leading: const Icon(Icons.bookmark, color: Colors.orange),
                title: Text(bookmark.title, style: const TextStyle(fontWeight: FontWeight.w500)),
                trailing: const Icon(Icons.open_in_new, size: 20, color: Colors.orange),
                onTap: () {
                  // Bookmark click karne par seedha Note Detail par jayenge
                  // (Apne route ke hisab se adjust karein)
                  context.push('/note_detail_screen', extra: bookmark); 
                },
              ),
            );
          }).toList(),
          const Divider(height: 32),
        ],
      ),
    );
  }
}
