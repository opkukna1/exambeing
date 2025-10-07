// lib/features/notes/screens/note_viewer_screen.dart

import 'package:flutter/material.dart';
// import '../../../helpers/database_helper.dart'; // ✅ FIX: Removed unused import

class NoteViewerScreen extends StatefulWidget {
  final Map<String, dynamic> topicData;
  final int? initialPage;
  const NoteViewerScreen({super.key, required this.topicData, this.initialPage});

  @override
  _NoteViewerScreenState createState() => _NoteViewerScreenState();
}

class _NoteViewerScreenState extends State<NoteViewerScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.topicData['topicName']),
        actions: const [],
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'PDF viewing functionality is currently unavailable.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ),
      ),
    );
  }
}
