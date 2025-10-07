// lib/features/bookmarks/screens/mcq_bookmarks_screen.dart

import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:exambeing/helpers/database_helper.dart';
import 'package:exambeing/models/mcq_bookmark_model.dart';

class McqBookmarksScreen extends StatefulWidget {
  const McqBookmarksScreen({super.key});

  @override
  // ✅ FIX: Removed underscore to make state class public
  McqBookmarksScreenState createState() => McqBookmarksScreenState();
}

// ✅ FIX: Removed underscore from class name
class McqBookmarksScreenState extends State<McqBookmarksScreen> {
  final dbHelper = DatabaseHelper.instance;
  late Future<Map<String, Map<String, List<McqBookmark>>>> _bookmarksFuture;

  @override
  void initState() {
    super.initState();
    _bookmarksFuture = _loadAndGroupBookmarks();
  }

  Future<Map<String, Map<String, List<McqBookmark>>>> _loadAndGroupBookmarks() async {
    final allBookmarks = await dbHelper.getAllMcqBookmarks();
    final groupedBySubject = groupBy(allBookmarks, (McqBookmark bm) => bm.subject);
    
    final finalMap = <String, Map<String, List<McqBookmark>>>{};
    groupedBySubject.forEach((subject, subjectList) {
      finalMap[subject] = groupBy(subjectList, (McqBookmark bm) => bm.topic);
    });
    return finalMap;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[50],
      appBar: AppBar(
        title: const Text('Bookmarked Questions'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: FutureBuilder<Map<String, Map<String, List<McqBookmark>>>>(
        future: _bookmarksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No bookmarked questions found.',
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          final groupedData = snapshot.data!;
          final subjects = groupedData.keys.toList();

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: subjects.length,
            itemBuilder: (context, subjectIndex) {
              final subject = subjects[subjectIndex];
              final topics = groupedData[subject]!;
              
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                child: ExpansionTile(
                  leading: const Icon(Icons.menu_book, color: Colors.blue),
                  title: Text(subject, style: const TextStyle(fontWeight: FontWeight.bold)),
                  children: topics.keys.map((topic) {
                    final questions = topics[topic]!;
                    return ExpansionTile(
                      tilePadding: const EdgeInsets.only(left: 30, right: 16),
                      leading: const Icon(Icons.topic_outlined, color: Colors.green),
                      title: Text(topic),
                      children: questions.map((question) {
                        return ListTile(
                          contentPadding: const EdgeInsets.only(left: 45, right: 16, bottom: 8),
                          title: Text(question.questionText),
                          subtitle: Text('Correct Answer: ${question.correctOption}', style: const TextStyle(color: Colors.green)),
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
