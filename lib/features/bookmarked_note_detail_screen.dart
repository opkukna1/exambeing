import 'package:flutter/material.dart';
import '../../../models/public_note_model.dart';

class BookmarkedNoteDetailScreen extends StatelessWidget {
  final PublicNote note;
  const BookmarkedNoteDetailScreen({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(note.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          note.content,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 18, height: 1.5),
        ),
      ),
    );
  }
}
