import 'package:flutter/material.dart';
import 'package:exambeing/models/public_note_model.dart'; // ✅ DummyNote ki jagah asli model
import 'package:exambeing/models/note_content_model.dart'; // ✅ Asli content ke liye model
import 'package:exambeing/helpers/database_helper.dart'; // ✅ Local DB ke liye
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ Firebase ke liye

class NoteDetailScreen extends StatefulWidget {
  // Ab hum PublicNote (list se) le rahe hain
  final PublicNote note; 
  
  const NoteDetailScreen({super.key, required this.note});

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  // State variables
  bool _isLoading = true;
  String _firebaseContent = ''; // Firebase se aane wala content
  String _userContent = ''; // User ka save kiya hua content
  
  final TextEditingController _userContentController = TextEditingController();
  final dbHelper = DatabaseHelper.instance;

  @override
  void initState() {
    super.initState();
    _loadAllContent(); // Saara content load karo
  }

  @override
  void dispose() {
    _userContentController.dispose();
    super.dispose();
  }

  // Firebase aur Local DB, dono se data load karo
  Future<void> _loadAllContent() async {
    setState(() => _isLoading = true);
    
    try {
      // 1. Firebase se "Lazy Load" karke asli content laao
      // (Hum 'noteContent' collection se 'widget.note.id' waala document la rahe hain)
      final contentDoc = await FirebaseFirestore.instance
          .collection('noteContent') // Aapke plan ke mutabik
          .doc(widget.note.id)
          .get();

      if (contentDoc.exists) {
        final contentModel = NoteContent.fromFirestore(contentDoc);
        _firebaseContent = contentModel.content;
      } else {
        _firebaseContent = 'Error: Full content not found.';
      }

      // 2. Local DB se user ke save kiye hue edits laao
      final userEdit = await dbHelper.getUserEdit(widget.note.id);
      if (userEdit != null) {
        _userContent = userEdit.userContent ?? '';
        _userContentController.text = _userContent;
        // (Yahaan hum highlights bhi load kar sakte hain)
      }
    } catch (e) {
      _firebaseContent = 'Error loading content: $e';
    }
    
    setState(() => _isLoading = false);
  }

  // User ke personal content ko Local DB mein save karo
  Future<void> _saveLocalNotes() async {
    final newContent = _userContentController.text.trim();
    
    // (Future ke liye: Yahaan highlights list bhi save kar sakte hain)
    final userEdit = UserNoteEdit.create(
      firebaseNoteId: widget.note.id,
      userContent: newContent,
      // highlights: [], 
    );

    try {
      await dbHelper.saveUserEdit(userEdit);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your personal notes saved locally!'),
            backgroundColor: Colors.green,
          ),
        );
        FocusScope.of(context).unfocus(); // Keyboard band karo
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save notes: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note.subSubjectName), // Sub-subject ka naam
      ),
      //  floatingActionButton: FloatingActionButton(
      //   onPressed: _saveLocalNotes,
      //   child: const Icon(Icons.save),
      //   tooltip: 'Save My Notes',
      // ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Title (List se aa raha hai)
                    Text(
                      widget.note.title,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Divider(height: 24),

                    // 2. Content (Firebase se "Lazy Load" hua)
                    Text(
                      _firebaseContent,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 18, height: 1.5),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // 3. User ka Personal Content (Local DB se)
                    Text(
                      'My Personal Notes',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '(Saved on your phone, not on Firebase)',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _userContentController,
                      maxLines: null, // Jitna user type kare, utna expand ho
                      decoration: InputDecoration(
                        hintText: 'Add your own content, highlights, or summary here...',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save My Notes'),
                        onPressed: _saveLocalNotes,
                      ),
                    ),
                    const SizedBox(height: 40), // Neeche extra space
                  ],
                ),
              ),
            ),
    );
  }
}
