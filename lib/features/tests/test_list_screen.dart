import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

// ✅ Model Update: Ab ye 'subjectId' bhi store karega
class TestInfo {
  final String id;
  final String title;
  final int duration;
  final String seriesId;
  final String subjectId; // New field for nested path

  TestInfo({
    required this.id,
    required this.title,
    required this.duration,
    required this.seriesId,
    required this.subjectId,
  });

  // Factory ab parent IDs bhi leta hai
  factory TestInfo.fromSnapshot(DocumentSnapshot doc, String seriesId, String subjectId) {
    final data = doc.data() as Map<String, dynamic>;
    return TestInfo(
      id: doc.id,
      title: data['title'] ?? 'Untitled Test',
      duration: (data['duration'] as num?)?.toInt() ?? 60,
      seriesId: seriesId,
      subjectId: subjectId,
    );
  }
}

class TestListScreen extends StatefulWidget {
  final String seriesId;
  final String subjectId; // ✅ Subject ID zaroori hai nested query ke liye
  final String subjectTitle; // AppBar ke liye title

  const TestListScreen({
    super.key, 
    required this.seriesId,
    required this.subjectId,
    required this.subjectTitle,
  });

  @override
  State<TestListScreen> createState() => _TestListScreenState();
}

class _TestListScreenState extends State<TestListScreen> {
  late Future<List<TestInfo>> _testsFuture;

  @override
  void initState() {
    super.initState();
    _testsFuture = _fetchTests();
  }

  // ✅ Updated: Nested Query Logic
  Future<List<TestInfo>> _fetchTests() async {
    try {
      // Path: testSeriesHome -> Series -> subjects -> Subject -> tests
      final snapshot = await FirebaseFirestore.instance
          .collection('testSeriesHome')
          .doc(widget.seriesId)
          .collection('subjects')
          .doc(widget.subjectId)
          .collection('tests')
          .get();
          
      return snapshot.docs.map((doc) => 
        TestInfo.fromSnapshot(doc, widget.seriesId, widget.subjectId)
      ).toList();
    } catch (e) {
      debugPrint("Error fetching tests: $e");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subjectTitle), // Subject ka naam dikhao (e.g. History)
      ),
      body: FutureBuilder<List<TestInfo>>(
        future: _testsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No tests found in this subject.\nThey will be added soon!',
                textAlign: TextAlign.center,
              ),
            );
          }

          final tests = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: tests.length,
            itemBuilder: (context, index) {
              final test = tests[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                elevation: 2,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.quiz, color: Colors.deepPurple),
                  ),
                  title: Text(test.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${test.duration} Minutes'),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: () {
                      // Series Test Screen par bhejo (TestInfo object ke sath)
                      context.push('/series-test-screen', extra: test);
                    },
                    child: const Text("Start"),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
