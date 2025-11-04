import 'package:flutter/material.dart';
import 'package:exambeing/features/notes/screens/public_notes_screen.dart'; // DummyNote Model ke liye

class NoteDetailScreen extends StatelessWidget {
  // Abhi hum DummyNote le rahe hain. Baad mein ise PublicNote model se badal denge.
  final DummyNote note; 
  
  const NoteDetailScreen({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(note.subSubjectName), // Sub-subject ka naam
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Title
              Text(
                note.title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              // 2. Image
              ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: Image.network(
                  note.imageUrl,
                  width: double.infinity,
                  height: 200, // Detail page par badi image
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => 
                    Container(
                      height: 200, 
                      color: Colors.grey[200], 
                      child: const Center(child: Text('Image not available')),
                    ),
                ),
              ),
              const SizedBox(height: 24),

              // 3. Content
              Text(
                note.content,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 18, height: 1.5),
              ),
              // (Dummy content short hai, asli content lamba hoga)
               const Text(
                "\nLorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. \n\nDuis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.",
                 style: TextStyle(fontSize: 18, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
