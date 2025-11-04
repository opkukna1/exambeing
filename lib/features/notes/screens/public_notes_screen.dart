import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ⬇️===== NAYE IMPORTS (Firebase Aur Models) =====⬇️
import 'package:exambeing/models/note_subject_model.dart';
import 'package:exambeing/models/note_sub_subject_model.dart';
import 'package:exambeing/models/public_note_model.dart';
// ⬆️============================================⬆️

// ❌ (Saara Dummy Data Models hata diya gaya hai)

class PublicNotesScreen extends StatefulWidget {
  const PublicNotesScreen({super.key});

  @override
  State<PublicNotesScreen> createState() => _PublicNotesScreenState();
}

class _PublicNotesScreenState extends State<PublicNotesScreen>
    with TickerProviderStateMixin {
  
  // Tab controllers ab `StreamBuilder` ke andar banenge
  TabController? _mainTabController;
  TabController? _subTabController;

  // Firebase services
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Streams (Taaki data live update ho)
  late Stream<QuerySnapshot> _mainSubjectsStream;
  late Stream<QuerySnapshot> _latestNotesStream;
  
  // Sub-subjects aur notes ke liye selected ID
  String? _selectedMainSubjectId;

  @override
  void initState() {
    super.initState();
    // Data streams ko initialize karo
    _mainSubjectsStream = _firestore.collection('noteSubjects').orderBy('name').snapshots();
    _latestNotesStream = _firestore
        .collection('publicNotes')
        .orderBy('timestamp', descending: true)
        .limit(10) // "Latest Notes" ke liye 10 ka limit
        .snapshots();
  }

  void _updateSubTabController(int length) {
    _subTabController?.dispose();
    _subTabController = TabController(length: length, vsync: this);
  }

  @override
  void dispose() {
    _mainTabController?.dispose();
    _subTabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exambeing Notes'),
        // ⬇️ Main Tab Bar ab StreamBuilder se banega ⬇️
        bottom: StreamBuilder<QuerySnapshot>(
          stream: _mainSubjectsStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const PreferredSize(
                preferredSize: Size.fromHeight(kToolbarHeight),
                child: Center(child: LinearProgressIndicator()),
              );
            }
            if (snapshot.data!.docs.isEmpty) {
              return const PreferredSize(
                preferredSize: Size.fromHeight(kToolbarHeight),
                child: Center(child: Text('No subjects found')),
              );
            }

            final mainSubjects = snapshot.data!.docs
                .map((doc) => NoteSubject.fromFirestore(doc))
                .toList();

            // Pehli baar main subject select karo
            if (_selectedMainSubjectId == null && mainSubjects.isNotEmpty) {
              _selectedMainSubjectId = mainSubjects[0].id;
            }

            // Main Tab Controller
            if (_mainTabController == null || _mainTabController!.length != mainSubjects.length) {
              _mainTabController?.dispose();
              _mainTabController = TabController(length: mainSubjects.length, vsync: this);
              _mainTabController!.addListener(() {
                if (_mainTabController!.indexIsChanging) {
                  setState(() {
                    _selectedMainSubjectId = mainSubjects[_mainTabController!.index].id;
                  });
                }
              });
            }

            return TabBar(
              controller: _mainTabController,
              isScrollable: true,
              tabs: mainSubjects.map((subject) => Tab(text: subject.name)).toList(),
            );
          },
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. "Latest Notes" Horizontal List (Firebase se)
          _buildLatestNotesList(context),
          
          // 2. Sub-Subject Tab Bar (Firebase se)
          _buildSubTabBar(context),
          
          const Divider(height: 1),

          // 3. Notes List (TabBarView) (Firebase se)
          Expanded(
            child: _subTabController == null
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _subTabController,
                    children: (_subTabController?.length ?? 0) == 0
                        ? [const Center(child: Text("No sub-subjects found."))]
                        : List.generate(_subTabController!.length, (index) {
                            // Yeh thoda complex hai, humein subTabController se ID nikaalna hoga
                            // Abhi ke liye, hum StreamBuilder ke data se ID lenge
                            return _buildNotesListForSubSubject(index);
                          }),
                  ),
          ),
        ],
      ),
    );
  }

  // "Latest Notes" (Firebase se)
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
            height: 80, // Text-only card
            child: StreamBuilder<QuerySnapshot>(
              stream: _latestNotesStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final notes = snapshot.data!.docs
                    .map((doc) => PublicNote.fromFirestore(doc))
                    .toList();
                
                if (notes.isEmpty) {
                  return const Center(child: Text('No latest notes.'));
                }

                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    return _buildLatestNoteCard(note);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // "Latest Notes" ka card
  Widget _buildLatestNoteCard(PublicNote note) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(right: 12),
      child: InkWell(
        // ⬇️===== Naya Route (Note Detail Ke Liye) =====⬇️
        onTap: () => context.push('/note-detail', extra: note),
        // ⬆️==========================================⬆️
        child: SizedBox(
          width: 220,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  note.subSubjectName, // Yeh Firebase se aa raha hai
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  note.title, // Yeh Firebase se aa raha hai
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // "Sub-Subject" Tab Bar (Firebase se)
  Widget _buildSubTabBar(BuildContext context) {
    if (_selectedMainSubjectId == null) {
      return Container(height: 50); // Agar main subject select nahi hua
    }

    return StreamBuilder<QuerySnapshot>(
      // `noteSubSubjects` collection se data laao
      // jahaan `mainSubjectId` match ho
      stream: _firestore
          .collection('noteSubSubjects')
          .where('mainSubjectId', isEqualTo: _selectedMainSubjectId)
          .orderBy('name')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 50, child: Center(child: LinearProgressIndicator()));
        }
        
        final subSubjects = snapshot.data!.docs
            .map((doc) => NoteSubSubject.fromFirestore(doc))
            .toList();
            
        // Sub-tab controller ko update karo
        if (_subTabController == null || _subTabController!.length != subSubjects.length) {
           _updateSubTabController(subSubjects.length);
        }

        if (subSubjects.isEmpty) {
          return const SizedBox(height: 50, child: Center(child: Text('No sub-subjects found.')));
        }

        return Container(
          color: Theme.of(context).appBarTheme.backgroundColor ?? Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: _subTabController,
            isScrollable: true,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Theme.of(context).textTheme.bodySmall?.color,
            tabs: subSubjects.map((sub) => Tab(text: sub.name)).toList(),
          ),
        );
      },
    );
  }


  // Vertical list (TabBarView ke andar)
  Widget _buildNotesListForSubSubject(int subTabIndex) {
    // Is function ko thoda update karna padega taaki yeh ID le sake
    // Abhi ke liye hum StreamBuilder ke andar hi query karenge
    
    // Pehle, humein Sub Tab Controller se SubSubject ID nikaalna hoga
    // Yeh thoda complex logic hai, humein sub-subjects ko state mein save karna hoga
    
    // AASAAN TAREKA: Hum `_buildSubTabBar` ke `StreamBuilder` se data le sakte hain
    
    if (_selectedMainSubjectId == null) {
      return const Center(child: Text("Select a main subject."));
    }

    return StreamBuilder<QuerySnapshot>(
      // 1. Pehle Sub-Subjects laao (taaki humein ID mil sake)
      stream: _firestore
          .collection('noteSubSubjects')
          .where('mainSubjectId', isEqualTo: _selectedMainSubjectId)
          .orderBy('name')
          .snapshots(),
      builder: (context, subSubjectSnapshot) {
        if (!subSubjectSnapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final subSubjects = subSubjectSnapshot.data!.docs
            .map((doc) => NoteSubSubject.fromFirestore(doc))
            .toList();

        if (subTabIndex >= subSubjects.length) {
          return const Center(child: Text("Loading..."));
        }
        
        // 2. Ab us Sub-Subject ki ID se notes laao
        final selectedSubSubjectId = subSubjects[subTabIndex].id;
        
        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('publicNotes')
              .where('subSubjectId', isEqualTo: selectedSubSubjectId)
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, noteSnapshot) {
            if (!noteSnapshot.hasData) return const Center(child: CircularProgressIndicator());
            
            final notes = noteSnapshot.data!.docs
                .map((doc) => PublicNote.fromFirestore(doc))
                .toList();

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
          },
        );
      },
    );
  }

  // Vertical list ka card
  Widget _buildNoteItemCard(PublicNote note) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        // ⬇️===== Naya Route (Note Detail Ke Liye) =====⬇️
        onTap: () => context.push('/note-detail', extra: note),
        // ⬆️==========================================⬆️
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          title: Text(
            note.title, // Firebase se
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            note.subSubjectName, // Firebase se
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.primary),
          ),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        ),
      ),
    );
  }
}
