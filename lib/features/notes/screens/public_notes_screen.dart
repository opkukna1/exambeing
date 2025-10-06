import 'package:flutter/material.dart';
import '../../../helpers/database_helper.dart';
import '../../../models/public_note_model.dart';
import '../../../models/subject_model.dart'; // Import Subject model
import '../../../services/firebase_data_service.dart';

class PublicNotesScreen extends StatefulWidget {
  const PublicNotesScreen({super.key});

  @override
  State<PublicNotesScreen> createState() => _PublicNotesScreenState();
}

class _PublicNotesScreenState extends State<PublicNotesScreen> {
  final FirebaseDataService _dataService = FirebaseDataService();
  late Future<List<PublicNote>> _notesFuture;
  late Future<List<Subject>> _subjectsFuture; // To hold the list of subjects for the filter

  late Set<String> _bookmarkedNoteIds;
  bool _isLoadingBookmarks = true;
  String _currentFilterTitle = 'Latest Notes';

  @override
  void initState() {
    super.initState();
    // Initially, fetch all latest notes
    _notesFuture = _dataService.getPublicNotes();
    // Fetch all subjects for the filter menu
    _subjectsFuture = _dataService.getAllSubjects();
    _loadBookmarkStatus();
  }
  
  Future<void> _loadBookmarkStatus() async {
    final bookmarkedNotes = await DatabaseHelper.instance.getAllBookmarkedNotes();
    _bookmarkedNoteIds = bookmarkedNotes.map((note) => note.id).toSet();
    if (mounted) {
      setState(() {
        _isLoadingBookmarks = false;
      });
    }
  }

  void _toggleBookmark(PublicNote note) async {
    // ... (This function is unchanged)
  }

  // Function to apply a filter
  void _applyFilter({Subject? subject}) {
    setState(() {
      if (subject == null) {
        _currentFilterTitle = 'Latest Notes';
        _notesFuture = _dataService.getPublicNotes();
      } else {
        _currentFilterTitle = subject.name;
        _notesFuture = _dataService.getPublicNotes(subjectId: subject.id);
      }
    });
  }
  
  // Function to show the filter options in a bottom sheet
  void _showFilterSheet(List<Subject> subjects) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Filter by Subject', style: Theme.of(context).textTheme.titleLarge),
              ),
              const Divider(),
              ListTile(
                title: const Text('All Latest Notes', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  _applyFilter(); // No subject = show all
                },
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: subjects.length,
                  itemBuilder: (context, index) {
                    final subject = subjects[index];
                    return ListTile(
                      title: Text(subject.name),
                      onTap: () {
                        Navigator.pop(context);
                        _applyFilter(subject: subject);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentFilterTitle),
        actions: [
          // Filter button now uses a FutureBuilder to get the list of subjects
          FutureBuilder<List<Subject>>(
            future: _subjectsFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const IconButton(
                  icon: Icon(Icons.filter_list_off),
                  onPressed: null,
                );
              }
              final subjects = snapshot.data!;
              return IconButton(
                icon: const Icon(Icons.filter_list),
                tooltip: 'Filter by Subject',
                onPressed: () => _showFilterSheet(subjects),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<PublicNote>>(
        future: _notesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting || _isLoadingBookmarks) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No notes found.'));
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
    );
  }

  Widget _buildNoteCard(PublicNote note) {
    final bool isBookmarked = _bookmarkedNoteIds.contains(note.id);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                note.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Divider(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    note.content,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 18, height: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(
                      isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    tooltip: 'Bookmark Note',
                    onPressed: () => _toggleBookmark(note),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_outlined),
                    tooltip: 'Share as Image',
                    onPressed: () {
                      // TODO: Add share as image logic here
                    },
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
