import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:exambeing/helpers/database_helper.dart';    // ✅ FIX: Using package import
import 'package:exambeing/models/question_model.dart';     // ✅ FIX: Using package import
import 'package:exambeing/models/public_note_model.dart';  // ✅ FIX: Using package import

class BookmarksHomeScreen extends StatelessWidget {
  const BookmarksHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Bookmarks'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.quiz_outlined), text: 'Questions'),
              Tab(icon: Icon(Icons.note_alt_outlined), text: 'Notes'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _McqBookmarksView(),
            _NoteBookmarksView(),
          ],
        ),
      ),
    );
  }
}

class _McqBookmarksView extends StatefulWidget {
  const _McqBookmarksView();
  @override
  State<_McqBookmarksView> createState() => _McqBookmarksViewState();
}

class _McqBookmarksViewState extends State<_McqBookmarksView> {
  late Future<List<Question>> _bookmarkedQuestionsFuture;

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  void _loadBookmarks() {
    setState(() {
      _bookmarkedQuestionsFuture = DatabaseHelper.instance.getAllBookmarkedQuestions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Question>>(
      future: _bookmarkedQuestionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No bookmarked questions yet.'));
        }
        final questions = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: questions.length,
          itemBuilder: (context, index) {
            final question = questions[index];
            return Card(
              child: ListTile(
                title: Text(question.questionText, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(question.explanation, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () async {
                    // ✅ FIX: Capture context-dependent objects before await
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    
                    await DatabaseHelper.instance.unbookmarkQuestion(question.questionText);
                    _loadBookmarks();

                    // Use the captured object after await
                    scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Bookmark removed')));
                  },
                ),
                onTap: () {
                  context.push('/bookmark-question-detail', extra: question);
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _NoteBookmarksView extends StatefulWidget {
  const _NoteBookmarksView();
  @override
  State<_NoteBookmarksView> createState() => __NoteBookmarksViewState();
}

class __NoteBookmarksViewState extends State<_NoteBookmarksView> {
  late Future<List<PublicNote>> _bookmarkedNotesFuture;

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  void _loadBookmarks() {
    setState(() {
      _bookmarkedNotesFuture = DatabaseHelper.instance.getAllBookmarkedNotes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PublicNote>>(
      future: _bookmarkedNotesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No bookmarked notes yet.'));
        }
        final notes = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: notes.length,
          itemBuilder: (context, index) {
            final note = notes[index];
            return Card(
              child: ListTile(
                title: Text(note.title),
                subtitle: Text(note.content, maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () async {
                    // ✅ FIX: Capture context-dependent objects before await
                    final scaffoldMessenger = ScaffoldMessenger.of(context);

                    await DatabaseHelper.instance.unbookmarkNote(note.id);
                    _loadBookmarks();

                    // Use the captured object after await
                    scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Bookmark removed')));
                  },
                ),
                onTap: () {
                  context.push('/bookmark-note-detail', extra: note);
                },
              ),
            );
          },
        );
      },
    );
  }
}
