import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

class NotesOnlineViewScreen extends StatelessWidget {
  final Map<String, dynamic> data;

  // Constructor name updated
  const NotesOnlineViewScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    // 1. Data unpack karein
    final String subjId = data['subjId'];
    final String subSubjId = data['subSubjId'];
    final String topicId = data['topicId'];
    final String subTopId = data['subTopId'];
    
    final String displayName = data['displayName']; // Hindi Name
    final String lang = data['lang'];
    final String mode = data['mode'];

    // 2. Document ID banana (Admin wale logic se match hona chahiye)
    final String docId = "${subjId}_${subSubjId}_${topicId}_${subTopId}".toLowerCase();

    // 3. Field Name banana (e.g., detailed_hi)
    final String fieldName = "${mode.toLowerCase().split(' ')[0]}_${lang == 'Hindi' ? 'hi' : 'en'}";

    return Scaffold(
      // AppBar with Back Button
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(displayName, style: const TextStyle(fontSize: 16)), // SubTopic Name
            Text("$mode Mode • $lang", style: const TextStyle(fontSize: 12)),
          ],
        ),
        backgroundColor: _getThemeColor(mode),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        // Sirf 1 Read lagega content load karne me
        future: FirebaseFirestore.instance.collection('notes_content').doc(docId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Error ya Empty check
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _buildErrorView("Content not found yet!");
          }

          var docData = snapshot.data!.data() as Map<String, dynamic>;

          // Content Check
          if (!docData.containsKey(fieldName) || docData[fieldName].toString().isEmpty) {
             return _buildErrorView("Content not available for $mode in $lang.");
          }

          // ✅ SHOW CONTENT
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: HtmlWidget(
              docData[fieldName], // HTML Render karega
              textStyle: const TextStyle(fontSize: 17, height: 1.6, color: Colors.black87),
            ),
          );
        },
      ),
    );
  }

  Color _getThemeColor(String mode) {
    if (mode == 'Revision') return Colors.orange.shade700;
    if (mode == 'Short') return Colors.red.shade700;
    return Colors.deepPurple;
  }

  Widget _buildErrorView(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.history_edu, size: 60, color: Colors.grey),
          const SizedBox(height: 10),
          Text(msg, style: const TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }
}
