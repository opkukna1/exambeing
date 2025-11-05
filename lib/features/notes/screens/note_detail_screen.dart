import 'package:flutter/material.dart';
import 'package:exambeing/models/public_note_model.dart';
import 'package:exambeing/models/note_content_model.dart';
import 'package:exambeing/helpers/database_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ⬇️===== NAYE IMPORTS (Rich Text Editor v2.0.7) =====⬇️
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'dart:convert'; // JSON encoding/decoding ke liye
// ⬆️================================================⬆️

class NoteDetailScreen extends StatefulWidget {
  final PublicNote note; 
  
  const NoteDetailScreen({super.key, required this.note});

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  quill.QuillController? _quillController; // v2.0.7 Controller
  bool _isLoading = true;
  final dbHelper = DatabaseHelper.instance;

  @override
  void initState() {
    super.initState();
    _loadAllContent();
  }

  @override
  void dispose() {
    _quillController?.dispose();
    super.dispose();
  }

  Future<void> _loadAllContent() async {
    setState(() => _isLoading = true);
    
    try {
      final userEdit = await dbHelper.getUserEdit(widget.note.id);

      if (userEdit != null && userEdit.quillContentJson != null) {
        // --- RAASTA 1: User ne pehle se edit save kiya hai ---
        final savedJson = jsonDecode(userEdit.quillContentJson!);
        final document = quill.Document.fromJson(savedJson); // v2.0.7 tareeka
        _quillController = quill.QuillController(
          document: document,
          selection: const TextSelection.collapsed(offset: 0),
        );
      } else {
        // --- RAASTA 2: User pehli baar note khol raha hai ---
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
        final document = quill.Document()..insert(0, firebaseContent); // v2.0.7 tareeka
        _quillController = quill.QuillController(
          document: document,
          selection: const TextSelection.collapsed(offset: 0),
        );
      }
    } catch (e) {
      debugPrint("Error loading note: $e");
      final document = quill.Document()..insert(0, 'Error loading content: $e');
      _quillController = quill.QuillController(
          document: document,
          selection: const TextSelection.collapsed(offset: 0),
        );
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _saveLocalNotes() async {
    if (_quillController == null) return;

    final quillJson = jsonEncode(_quillController!.document.toDelta().toJson());
    
    final userEdit = UserNoteEdit(
      firebaseNoteId: widget.note.id,
      quillContentJson: quillJson,
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
        FocusScope.of(context).unfocus();
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
        title: Text(widget.note.subSubjectName),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            onPressed: _saveLocalNotes,
            tooltip: 'Save My Notes',
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          // ⬇️===== YEH HAI NAYA SAHI CODE (Quill v2.0.7) =====⬇️
          : Column(
              children: [
                // Toolbar (Puraana tareeka)
                quill.QuillToolbar.basic(
                  controller: _quillController!,
                  showBackgroundColorButton: true, // Highlight
                  showColorButton: true, // Font color
                ),
                const Divider(height: 1, thickness: 1),

                // Editor (Puraana tareeka)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: quill.QuillEditor( // ✅ 'QuillEditor' (bina .basic ke)
                      controller: _quillController!,
                      scrollController: ScrollController(),
                      focusNode: FocusNode(),
                      autoFocus: false, // ✅ 'autoFocus' yahaan hai
                      readOnly: false,
                      expands: false,
                      padding: EdgeInsets.zero,
                      scrollable: true,
                    ),
                  ),
                ),
              ],
            ),
          // ⬆️=============================================⬆️
    );
  }
}
