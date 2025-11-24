import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

// Model bana lete hain taaki code saaf rahe
class TestInfo {
  final String id;
  final String title;
  final int duration;
  final String seriesId;

  TestInfo({
    required this.id,
    required this.title,
    required this.duration,
    required this.seriesId,
  });

  factory TestInfo.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TestInfo(
      id: doc.id,
      title: data['title'] ?? 'Untitled Test',
      duration: (data['duration'] as num?)?.toInt() ?? 60,
      seriesId: data['seriesId'] ?? '',
    );
  }
}


class TestListScreen extends StatefulWidget {
  final String seriesId; // Ye 'cet_12th' jaisi ID Home Screen se aayegi
  
  const TestListScreen({super.key, required this.seriesId});

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

  // Firestore se 'Tests' collection se data fetch karo
  Future<List<TestInfo>> _fetchTests() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Tests') // Ye 'Tests' collection se data layega
          .where('seriesId', isEqualTo: widget.seriesId) // Sirf is series ke (jaise 'cet_12th')
          .get();
          
      return snapshot.docs.map((doc) => TestInfo.fromSnapshot(doc)).toList();
    } catch (e) {
      print("Error fetching tests: $e");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Tests'), // Aap yahan series ka naam bhi dikha sakte ho
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
                'No tests found for this series.\nThey will be added soon!',
                textAlign: TextAlign.center,
              ),
            );
          }

          final tests = snapshot.data!;

          // Test ki list dikhao
          return ListView.builder(
            itemCount: tests.length,
            itemBuilder: (context, index) {
              final test = tests[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(test.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${test.duration} Minutes'),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded),
                  onTap: () {
                    // Ab is test ko shuru karne ke liye
                    // test screen par bhej do
                    context.push('/series-test-screen', extra: test);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
