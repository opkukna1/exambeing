// lib/features/notes/screens/note_viewer_screen.dart

import 'package:flutter/material.dart';
// import 'package:pdfx/pdfx.dart'; // REMOVED: PDFX import
import '../../../helpers/database_helper.dart';

class NoteViewerScreen extends StatefulWidget {
  final Map<String, dynamic> topicData;
  final int? initialPage;
  const NoteViewerScreen({super.key, required this.topicData, this.initialPage});

  @override
  _NoteViewerScreenState createState() => _NoteViewerScreenState();
}

class _NoteViewerScreenState extends State<NoteViewerScreen> {
  // All state variables related to the PDF viewer have been removed.

  @override
  void initState() {
    super.initState();
    // All logic for initializing the PDF controller has been removed.
  }

  @override
  void dispose() {
    // All logic for disposing the PDF controller has been removed.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.topicData['topicName']),
        // REMOVED: Actions like bookmarking and night mode are no longer needed.
        actions: const [],
      ),
      // REPLACED: The PDF viewer has been replaced with a placeholder message.
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
