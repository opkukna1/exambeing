import 'package:flutter/material.dart';
import 'package:exambeing/models/public_note_model.dart';
import 'package:exambeing/models/note_content_model.dart';
import 'package:exambeing/helpers/database_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'dart:convert';

class NoteDetailScreen extends StatefulWidget {
  final PublicNote note;

  const NoteDetailScreen({super.key, required this.note});

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  QuillController? _quillController;
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
        // --- Local saved version load karo ---
        final savedJson = jsonDecode(userEdit.quillContentJson!);
        final document = Document.fromJson(savedJson);
        _quillController = QuillController(
          document: document,
          selection: const TextSelection.collapsed(offset: 0),
        );
      } else {
        // --- Firebase se load karo ---
        final contentDoc = await FirebaseFirestore.instance
            .collection('noteContent')
            .doc(widget.note.id)
            .get();

        String firebaseContent = 'Error: Full content not found.';
        if (contentDoc.exists) {
          final contentModel = NoteContent.fromFirestore(contentDoc);
          firebaseContent = contentModel.content;
        }

        final document = Document()..insert(0, firebaseContent);
        _quillController = QuillController(
          document: document,
          selection: const TextSelection.collapsed(offset: 0),
        );
      }
    } catch (e) {
      debugPrint("Error loading note: $e");
      final document = Document()..insert(0, 'Error loading content: $e');
      _quillController = QuillController(
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
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ✅ नया Toolbar (v11 compatible)
                QuillSimpleToolbar(
                  configurations: QuillSimpleToolbarConfigurations(
                    controller: _quillController!,
                    showBackgroundColorButton: true,
                    showColorButton: true,
                  ),
                ),

                const Divider(height: 1, thickness: 1),

                // ✅ नया Editor (autoFocus हटाया गया)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: QuillEditor.basic(
                      configurations: QuillEditorConfigurations(
                        controller: _quillController!,
                        readOnly: false,
                        sharedConfigurations: const QuillSharedConfigurations(
                          locale: Locale('en'),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
