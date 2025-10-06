import 'package:flutter/material.dart';
import '../../../helpers/database_helper.dart';

class AddEditNoteScreen extends StatefulWidget {
  // If a note is passed, we are editing. If not, we are adding.
  final MyNote? note;
  const AddEditNoteScreen({super.key, this.note});

  @override
  State<AddEditNoteScreen> createState() => _AddEditNoteScreenState();
}

class _AddEditNoteScreenState extends State<AddEditNoteScreen> {
  final TextEditingController _contentController = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _isEditing = true;
      _contentController.text = widget.note!.content;
    }
  }

  void _saveNote() async {
    final content = _contentController.text;
    if (content.isEmpty) {
      // Don't save empty notes
      return;
    }

    if (_isEditing) {
      // Update existing note
      final updatedNote = MyNote(
        id: widget.note!.id,
        content: content,
        createdAt: widget.note!.createdAt, // Keep original creation date
      );
      await DatabaseHelper.instance.update(updatedNote);
    } else {
      // Create new note
      final newNote = MyNote(
        content: content,
        createdAt: DateTime.now().toIso8601String(), // Save current time
      );
      await DatabaseHelper.instance.create(newNote);
    }

    // Go back to the previous screen and signal that it should refresh
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextField(
          controller: _contentController,
          autofocus: true,
          maxLines: null, // Allows the text field to expand
          expands: true,
          decoration: const InputDecoration(
            hintText: 'Write your important facts here...',
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }
}
