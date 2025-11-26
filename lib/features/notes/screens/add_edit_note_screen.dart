import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Date format ke liye
import 'package:exambeing/helpers/database_helper.dart';
// Import path check karein
import 'package:exambeing/models/my_note_model.dart'; 

class AddEditNoteScreen extends StatefulWidget {
  final MyNote? note; // Agar null hai to New, warna Edit

  const AddEditNoteScreen({super.key, this.note});

  @override
  State<AddEditNoteScreen> createState() => _AddEditNoteScreenState();
}

class _AddEditNoteScreenState extends State<AddEditNoteScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    // Agar purana note edit kar rahe hain to data bharo, nahi to khali rakho
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(text: widget.note?.content ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    // Agar dono khali hain to save mat karo
    if (title.isEmpty && content.isEmpty) {
      return; 
    }

    // Date format: 26 Nov 2025, 10:30 PM
    final date = DateFormat('d MMM yyyy, h:mm a').format(DateTime.now());

    final note = MyNote(
      id: widget.note?.id, // Edit ke time purani ID rahegi, New me null
      title: title.isEmpty ? 'Untitled Note' : title,
      content: content,
      createdAt: date,
    );

    if (widget.note == null) {
      // New Create
      await DatabaseHelper.instance.create(note);
    } else {
      // Update
      await DatabaseHelper.instance.update(note);
    }

    if (mounted) {
      Navigator.pop(context, true); // True return karega taaki list refresh ho
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          widget.note == null ? 'New Note' : 'Edit Note',
          style: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: TextButton(
              onPressed: _saveNote,
              style: TextButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              ),
              child: const Text("Save", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Box 1: Title Input (Bold & Big)
            TextField(
              controller: _titleController,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: 'Title',
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none, // Line hata di taaki clean dikhe
              ),
            ),
            
            const Divider(thickness: 1, height: 20),
            
            // Box 2: Content Input (Full Screen & Multiline)
            Expanded(
              child: TextField(
                controller: _contentController,
                style: const TextStyle(fontSize: 18, height: 1.5, color: Colors.black87),
                maxLines: null, // Unlimited lines allow karega
                expands: true,  // Pura bacha hua space lega
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  hintText: 'Start writing here...',
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
