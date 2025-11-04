import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// --- Dummy Data Models (Firebase ke liye placeholder) ---
class DummyNote {
  final String id;
  final String title;
  final String content;
  final String imageUrl;
  final String subSubjectName; // e.g., 'Rajasthan Itihas'

  DummyNote({
    required this.id,
    required this.title,
    required this.content,
    required this.imageUrl,
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
      imageUrl: 'https://placehold.co/150x100/E0E0E0/909090?text=Note+1',
      subSubjectName: 'Rajasthan Itihas',
    ),
    DummyNote(
      id: 'n2',
      title: 'Latest Note: Ashok Samrat',
      content: 'Yeh poora content hai...',
      imageUrl: 'https://placehold.co/150x100/E0E0E0/909090?text=Note+2',
      subSubjectName: 'Bharatiya Itihas',
    ),
    DummyNote(
      id: 'n3',
      title: 'Latest Note: Nadiyan',
      content: 'Yeh poora content hai...',
      imageUrl: 'https://placehold.co/150x100/E0E0E0/909090?text=Note+3',
      subSubjectName: 'Bharat Bhugol',
    ),
  ];

  // Dummy function to get notes for a sub-subject
  List<DummyNote> _getNotesForSubSubject(String subSubjectId) {
    // Abhi ke liye, sabhi notes mein se filter kar rahe hain.
    // Asli app mein, yeh Firebase query hogi.
    if (subSubjectId == 'sub1_1') {
      return [
        DummyNote(id: 'n4', title: 'Rajasthan Note 1: Jaipur', content: '...', imageUrl: 'https://placehold.co/100x100/E0E0E0/909090?text=Jaipur', subSubjectName: 'Rajasthan Itihas'),
        DummyNote(id: 'n5', title: 'Rajasthan Note 2: Jodhpur', content: '...', imageUrl: 'https://placehold.co/100x100/E0E0E0/909090?text=Jodhpur', subSubjectName: 'Rajasthan Itihas'),
      ];
    }
    if (subSubjectId == 'sub1_2') {
       return [
        DummyNote(id: 'n6', title: 'Bharat Note 1: Gupta Samrajya', content: '...', imageUrl: 'https://placehold.co/100x100/E0E0E0/909090?text=Gupta', subSubjectName: 'Bharatiya Itihas'),
      ];
    }
    return []; // Baaki ke liye khaali list
  }
  // --- End of Dummy Data ---

  @override
  void initState() {
    super.initState();
    // Main Tab Controller
    _mainTabController =
        TabController(length: _mainSubjects.length, vsync: this);
    
    // Pehle main tab ke liye Sub Tab Controller
    _subTabController = TabController(
        length: _mainSubjects[0].subSubjects.length, vsync: this);

    // Main tab badalne par sub-tabs ko update karo
    _mainTabController.addListener(_handleMainTabSelection);
  }

  void _handleMainTabSelection() {
    if (_mainTabController.indexIsChanging) {
      // Main tab badal gaya hai
      setState(() {
        // Puraana sub-tab controller dispose karo (agar zaroori ho)
        _subTabController.dispose();
        // Naya sub-tab controller banao
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
    // Current main subject ke sub-subjects
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
              // Dark mode ke liye text color theek karna
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
                // Har sub-subject ke liye notes ki list
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
            'Latest Notes', // "Top News" ki jagah
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160, // Horizontal list ki height
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.network(
                note.imageUrl,
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
                // Error hone par placeholder
                errorBuilder: (context, error, stackTrace) => 
                  Container(
                    height: 100, 
                    color: Colors.grey[200], 
                    child: const Icon(Icons.broken_image),
                  ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  note.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
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
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.subSubjectName, // e.g., 'Rajasthan Itihas'
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      note.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    // Aap yahaan content snippet bhi dikha sakte hain
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Image
              ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.network(
                  note.imageUrl,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => 
                    Container(
                      width: 100, 
                      height: 100, 
                      color: Colors.grey[200], 
                      child: const Icon(Icons.broken_image),
                    ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
