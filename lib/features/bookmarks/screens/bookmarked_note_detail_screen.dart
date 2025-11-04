import 'package:flutter/material.dart';
// ⬇️===== YEH HAI FIX (PublicNote -> BookmarkedNote) =====⬇️
import '../../../models/bookmarked_note_model.dart'; 
// ⬆️====================================================⬆️

class BookmarkedNoteDetailScreen extends StatelessWidget {
  // ⬇️===== YEH HAI FIX (PublicNote -> BookmarkedNote) =====⬇️
  final BookmarkedNote note;
  const BookmarkedNoteDetailScreen({super.key, required this.note});
  // ⬆️====================================================⬆️

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(note.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          // ✅ Ab yeh error nahi dega, kyonki BookmarkedNote.content 'String' hai
          note.content,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 18, height: 1.5),
        ),
      ),
    );
  }
}
