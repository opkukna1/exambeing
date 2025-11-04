import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// --- Dummy Data Models (Firebase ke liye placeholder) ---
// (Image URL hata diya gaya hai)
class DummyNote {
  final String id;
  final String title;
  final String content;
  final String subSubjectName; // e.g., 'Rajasthan Itihas'

  DummyNote({
    required this.id,
    required this.title,
    required this.content,
    required this.subSubjectName,
  });
}

class DummySubSubject {
  final String id;
  final String name;
  DummySubSubject({required this.id, required this.name});
}

class DummyMainSubject {
  final String id;
  final String name;
  final List<DummySubSubject> subSubjects;

  DummyMainSubject({
    required this.id,
    required this.name,
    required this.subSubjects,
  });
}
// --- End of Dummy Data Models ---

class PublicNotesScreen extends StatefulWidget {
  const PublicNotesScreen({super.key});

  @override
  State<PublicNotesScreen> createState() => _PublicNotesScreenState();
}

class _PublicNotesScreenState extends State<PublicNotesScreen>
    with TickerProviderStateMixin {
  late TabController _mainTabController;
  late TabController _subTabController;

  // --- Dummy Data (Ise hum baad mein Firebase se replace karenge) ---
  final List<DummyMainSubject> _mainSubjects = [
    DummyMainSubject(
      id: 'sub1',
      name: 'इतिहास (Itihas)',
      subSubjects: [
        DummySubSubject(id: 'sub1_1', name: 'Rajasthan Itihas'),
        DummySubSubject(id: 'sub1_2', name: 'Bharatiya Itihas'),
        DummySubSubject(id: 'sub1_3', name: 'Visv Itihas'),
      ],
    ),
    DummyMainSubject(
      id: 'sub2',
      name: 'भूगोल (Bhugol)',
      subSubjects: [
        DummySubSubject(id: 'sub2_1', name: 'Bharat Bhugol'),
        DummySubSubject(id: 'sub2_2', name: 'Visv Bhugol'),
      ],
    ),
    DummyMainSubject(
      id: 'sub3',
      name: 'Politics',
      subSubjects: [
        DummySubSubject(id: 'sub3_1', name: 'Indian Constitution'),
        DummySubSubject(id: 'sub3_2', name: 'Political Theory'),
      ],
    ),
  ];

  final List<DummyNote> _latestNotes = [
    DummyNote(
      id: 'n1',
      title: 'Latest Note: Maharana Pratap Ki Kahani',
      content: 'Yeh poora content hai...',
      subSubjectName: 'Rajasthan Itihas',
    ),
    DummyNote(
      id: 'n2',
      title: 'Latest Note: Ashok Samrat',
      content: 'Yeh poora content hai...',
      subSubjectName: 'Bharatiya Itihas',
    ),
    DummyNote(
      id: 'n3',
      title: 'Latest Note: Nadiyan',
      content: 'Yeh poora content hai...',
      subSubjectName: 'Bharat Bhugol',
    ),
  ];

  // Dummy function to get notes for a sub-subject
  List<DummyNote> _getNotesForSubSubject(String subSubjectId) {
    if (subSubjectId == 'sub1_1') {
      return [
        DummyNote(id: 'n4', title: 'Rajasthan Note 1: Jaipur', content: '...', subSubjectName: 'Rajasthan Itihas'),
        DummyNote(id: 'n5', title: 'Rajasthan Note 2: Jodhpur', content: '...', subSubjectName: 'Rajasthan Itihas'),
      ];
    }
    if (subSubjectId == 'sub1_2') {
       return [
        DummyNote(id: 'n6', title: 'Bharat Note 1: Gupta Samrajya', content: '...', subSubjectName: 'Bharatiya Itihas'),
      ];
    }
    return []; // Baaki ke liye khaali list
  }
  // --- End of Dummy Data ---

  @override
  void initState() {
    super.initState();
    _mainTabController =
        TabController(length: _mainSubjects.length, vsync: this);
    _subTabController = TabController(
        length: _mainSubjects[0].subSubjects.length, vsync: this);
    _mainTabController.addListener(_handleMainTabSelection);
  }

  void _handleMainTabSelection() {
    if (_mainTabController.indexIsChanging) {
      setState(() {
        _subTabController.dispose();
        _subTabController = TabController(
          length: _mainSubjects[_mainTabController.index].subSubjects.length,
          vsync: this,
        );
      });
    }
  }

  @override
  void dispose() {
    _mainTabController.removeListener(_handleMainTabSelection);
    _mainTabController.dispose();
    _subTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentSubSubjects =
        _mainSubjects[_mainTabController.index].subSubjects;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exambeing Notes'),
        bottom: TabBar(
          controller: _mainTabController,
          isScrollable: true,
          tabs: _mainSubjects.map((subject) => Tab(text: subject.name)).toList(),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. "Latest Notes" Horizontal List
          _buildLatestNotesList(context),
          
          // 2. Sub-Subject Tab Bar
          Container(
            color: Theme.of(context).appBarTheme.backgroundColor ?? Theme.of(context).colorScheme.surface,
            child: TabBar(
              controller: _subTabController,
              isScrollable: true,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Theme.of(context).textTheme.bodySmall?.color,
              tabs: currentSubSubjects
                  .map((sub) => Tab(text: sub.name))
                  .toList(),
            ),
          ),
          const Divider(height: 1),

          // 3. Notes List (TabBarView)
          Expanded(
            child: TabBarView(
              controller: _subTabController,
              children: currentSubSubjects.map((subSubject) {
                final notes = _getNotesForSubSubject(subSubject.id);
                return _buildNotesListView(notes);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // "Latest Notes" (Top News jaisa)
  Widget _buildLatestNotesList(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Latest Notes',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 80, // ⬇️ Height kam kar di hai (image nahi hai)
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _latestNotes.length,
              itemBuilder: (context, index) {
                final note = _latestNotes[index];
                return _buildLatestNoteCard(note);
              },
            ),
          ),
        ],
      ),
    );
  }

  // "Latest Notes" ka card
  Widget _buildLatestNoteCard(DummyNote note) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () => context.push('/note-detail', extra: note),
        child: SizedBox(
          width: 220, // Card ki chaudai
          // ⬇️ Column ki jagah simple Padding (image nahi hai)
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  note.subSubjectName,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  note.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // ⬆️=============================================
        ),
      ),
    );
  }


  // Vertical list (screenshot jaisi)
  Widget _buildNotesListView(List<DummyNote> notes) {
    if (notes.isEmpty) {
      return const Center(child: Text('No notes found in this sub-subject.'));
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        return _buildNoteItemCard(note);
      },
    );
  }

  // Vertical list ka card
  Widget _buildNoteItemCard(DummyNote note) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => context.push('/note-detail', extra: note),
        // ⬇️ Row ki jagah simple ListTile (image nahi hai)
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          title: Text(
            note.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            note.subSubjectName,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.primary),
          ),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        ),
        // ⬆️=============================================
      ),
    );
  }
}
