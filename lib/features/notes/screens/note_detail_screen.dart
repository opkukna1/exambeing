import 'package.flutter/material.dart';
import 'package:exambeing/models/public_note_model.dart'; // ✅ Asli model
import 'package:exambeing/models/note_content_model.dart'; // ✅ Asli content ke liye model
import 'package:exambeing/helpers/database_helper.dart'; // ✅ Local DB ke liye
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ Firebase ke liye

// ⬇️===== NAYE IMPORTS (Rich Text Editor) =====⬇️
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'dart:convert'; // JSON encoding/decoding ke liye
// ⬆️==========================================⬆️

class NoteDetailScreen extends StatefulWidget {
  final PublicNote note; 
  
  const NoteDetailScreen({super.key, required this.note});

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  // ❌ (Puraana simple text controller hata diya)
  // final TextEditingController _userContentController = TextEditingController();
  
  // ⬇️===== NAYA QUILL CONTROLLER (Editor Ke Liye) =====⬇️
  quill.QuillController? _quillController;
  // ⬆️================================================⬆️
  
  bool _isLoading = true;
  final dbHelper = DatabaseHelper.instance;

  @override
  void initState() {
    super.initState();
    _loadAllContent(); // Saara content (Firebase + Local) load karo
  }

  @override
  void dispose() {
    _quillController?.dispose(); // Controller ko dispose karo
    super.dispose();
  }

  // Firebase (Read-Only) aur Local DB (Edits) dono se data load karo
  Future<void> _loadAllContent() async {
    setState(() => _isLoading = true);
    
    try {
      // 1. Local DB se user ke save kiye hue edits laao
      final userEdit = await dbHelper.getUserEdit(widget.note.id);

      if (userEdit != null && userEdit.quillContentJson != null) {
        // --- RAASTA 1: User ne pehle se edit save kiya hai ---
        // Local DB se saved JSON ko load karo
        final savedJson = jsonDecode(userEdit.quillContentJson!);
        final document = quill.Document.fromJson(savedJson);
        _quillController = quill.QuillController(
          document: document,
          selection: const TextSelection.collapsed(offset: 0),
        );
      } else {
        // --- RAASTA 2: User pehli baar note khol raha hai ---
        // Firebase se asli content "Lazy Load" karke laao
        final contentDoc = await FirebaseFirestore.instance
            .collection('noteContent')
            .doc(widget.note.id)
            .get();

        String firebaseContent = 'Error: Full content not found.';
        if (contentDoc.exists) {
          final contentModel = NoteContent.fromFirestore(contentDoc);
          firebaseContent = contentModel.content;
        }

        // Firebase ke simple text ko Quill Document mein "Clone" (copy) karo
        final document = quill.Document()..insert(0, firebaseContent);
        _quillController = quill.QuillController(
          document: document,
          selection: const TextSelection.collapsed(offset: 0),
        );
      }
    } catch (e) {
      // Koi bhi error aaye to ek khaali editor dikhao
      debugPrint("Error loading note: $e");
      final document = quill.Document()..insert(0, 'Error loading content: $e');
      _quillController = quill.QuillController(
          document: document,
          selection: const TextSelection.collapsed(offset: 0),
        );
    }
    
    setState(() => _isLoading = false); // Loading band karo
  }

  // User ke personal content (Quill JSON) ko Local DB mein save karo
  Future<void> _saveLocalNotes() async {
    if (_quillController == null) return; // Agar controller hi nahi hai

    // Editor ke poore content ko JSON mein badlo
    final quillJson = jsonEncode(_quillController!.document.toDelta().toJson());
    
    // Naya DB model (v11) banayo
    final userEdit = UserNoteEdit(
      firebaseNoteId: widget.note.id,
      quillContentJson: quillJson, // ❌ userContent ki jagah naya field
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
        // ⬇️===== NAYA SAVE BUTTON =====⬇️
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            onPressed: _saveLocalNotes,
            tooltip: 'Save My Notes',
          )
        ],
        // ⬆️==========================⬆️
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ⬇️===== NAYA RICH TEXT EDITOR TOOLBAR =====⬇️
                // (Bold, Italic, Color, Highlight waale buttons)
                quill.QuillToolbar.simple(
                  configurations: quill.QuillSimpleToolbarConfigurations(
                    controller: _quillController!,
                    sharedConfigurations: const quill.QuillSharedConfigurations(
                      locale: Locale('en'),
                    ),
                  ),
                ),
                const Divider(height: 1, thickness: 1),
                // ⬆️========================================⬆️

                // ⬇️===== NAYA RICH TEXT EDITOR =====⬇️
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: quill.QuillEditor.basic(
                      configurations: quill.QuillBasicEditorConfigurations(
                        controller: _quillController!,
                        readOnly: false, // User edit kar sakta hai
                        sharedConfigurations: const quill.QuillSharedConfigurations(
                          locale: Locale('en'),
                        ),
                      ),
                    ),
                  ),
                ),
                // ⬆️===============================⬆️
              ],
            ),
    );
  }
}
