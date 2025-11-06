import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
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
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _isEditing = widget.note != null;
    _loadNoteContent();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadNoteContent() {
    if (_isEditing && widget.note!.content.isNotEmpty) {
      try {
        final json = jsonDecode(widget.note!.content);
        _controller = QuillController(
          document: Document.fromJson(json),
          selection: const TextSelection.collapsed(offset: 0),
        );
      } catch (e) {
        _controller = QuillController(
          document: Document()..insert(0, widget.note!.content),
          selection: const TextSelection.collapsed(offset: 0),
        );
      }
    } else {
      _controller = QuillController.basic();
    }
  }

  void _saveNote() async {
    final contentJson = jsonEncode(_controller.document.toDelta().toJson());
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
        content: contentJson,
        createdAt: widget.note!.createdAt,
      );
      await DatabaseHelper.instance.update(updatedNote);
    } else {
      final newNote = MyNote(
        content: contentJson,
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
          QuillSimpleToolbar( // Use QuillSimpleToolbar instead of QuillToolbar.simple
            controller: _controller,
            configurations: const QuillSimpleToolbarConfigurations(), // This might work now
          ),
          const Divider(height: 1, thickness: 1, color: Colors.grey),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: QuillEditor.basic(
                controller: _controller,
                // Removed configurations to let it use defaults if it fails again
                // If it needs config, it might be passed differently now.
              ),
            ),
          ),
        ],
      ),
    );
  }
}
