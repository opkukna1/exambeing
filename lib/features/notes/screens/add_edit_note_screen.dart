import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart'; // Delta import zaroori hai
import '../../../helpers/database_helper.dart';

class AddEditNoteScreen extends StatefulWidget {
  final MyNote? note;
  const AddEditNoteScreen({super.key, this.note});

  @override
  State<AddEditNoteScreen> createState() => _AddEditNoteScreenState();
}

class _AddEditNoteScreenState extends State<AddEditNoteScreen> {
  late QuillController _controller;
  bool _isEditing = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _isEditing = widget.note != null;
    _loadNoteContent();
  }

  // Note content load karne ka function (rich text ya plain text dono handle karega)
  void _loadNoteContent() {
    if (_isEditing && widget.note!.content.isNotEmpty) {
      try {
        // Koshish karo JSON (rich text) parse karne ki
        final json = jsonDecode(widget.note!.content);
        _controller = QuillController(
          document: Document.fromJson(json),
          selection: const TextSelection.collapsed(offset: 0),
        );
      } catch (e) {
        // Agar JSON fail ho (purana plain text note), toh normal text load karo
        _controller = QuillController(
          document: Document()..insert(0, widget.note!.content),
          selection: const TextSelection.collapsed(offset: 0),
        );
      }
    } else {
      // Naya note hai toh blank controller
      _controller = QuillController.basic();
    }
  }

  void _saveNote() async {
    // Document ko JSON format mein convert karo taaki styles save hon
    final contentJson = jsonEncode(_controller.document.toDelta().toJson());
    // Plain text bhi check kar lo taaki empty note save na ho
    final plainText = _controller.document.toPlainText().trim();

    if (plainText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot save an empty note')),
      );
      return;
    }

    if (_isEditing) {
      final updatedNote = MyNote(
        id: widget.note!.id,
        content: contentJson, // JSON save karo
        createdAt: widget.note!.createdAt,
      );
      await DatabaseHelper.instance.update(updatedNote);
    } else {
      final newNote = MyNote(
        content: contentJson, // JSON save karo
        createdAt: DateTime.now().toIso8601String(),
      );
      await DatabaseHelper.instance.create(newNote);
    }

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Note' : 'Add Note'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            onPressed: _saveNote,
            tooltip: 'Save Note',
          ),
        ],
      ),
      body: Column(
        children: [
          // TOOLBAR YAHAN HAI (v11.5.0 style)
          QuillSimpleToolbar(
            controller: _controller,
            configurations: const QuillSimpleToolbarConfigurations(
              showFontFamily: false, // Font family hide kar sakte ho agar nahi chahiye
              showFontSize: false,   // Font size bhi hide kar sakte ho simple rakhne ke liye
              multiRowsDisplay: false, // Single row mein toolbar dikhega
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Colors.grey),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              // EDITOR YAHAN HAI
              child: QuillEditor(
                controller: _controller,
                scrollController: ScrollController(),
                focusNode: _focusNode,
                configurations: const QuillEditorConfigurations(
                  placeholder: 'Write your important facts here...',
                  autoFocus: true,
                  expands: false,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
