import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:exambeing/models/question_model.dart';
import 'package:exambeing/services/ad_manager.dart';

class TestGeneratorScreen extends StatefulWidget {
  const TestGeneratorScreen({super.key});

  @override
  State<TestGeneratorScreen> createState() => _TestGeneratorScreenState();
}

class _TestGeneratorScreenState extends State<TestGeneratorScreen> {
  // Key = TopicID, Value = Number of Questions requested
  final Map<String, int> _topicCounts = {};
  
  // Total Question Counter (UI dikhane ke liye)
  int get _totalQuestions => _topicCounts.values.fold(0, (sum, count) => sum + count);

  bool _isLoading = false;

  // 1. Subjects Fetch karna
  Stream<QuerySnapshot> _getSubjects() {
    return FirebaseFirestore.instance.collection('subjects').snapshots();
  }

  // 2. Topics Fetch karna (Subject ID ke basis par)
  Stream<QuerySnapshot> _getTopics(String subjectId) {
    return FirebaseFirestore.instance
        .collection('topics')
        .where('subjectId', isEqualTo: subjectId)
        .snapshots();
  }

  // 🔥 MAGIC FUNCTION: Specific Count ke sath Test Generate karna
  Future<void> _generateTest() async {
    // 1. Validation
    if (_totalQuestions == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add at least one question from any topic!")),
      );
      return;
    }

    if (_totalQuestions > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Maximum limit is 100 questions per test.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      List<Question> finalQuestionsList = [];

      // 2. Loop through selected topics
      // Map ke har entry (TopicID -> Count) ko process karo
      for (var entry in _topicCounts.entries) {
        String topicId = entry.key;
        int requestedCount = entry.value;

        if (requestedCount <= 0) continue;

        // A. Is topic ke SARE question IDs lao
        final query = await FirebaseFirestore.instance
            .collection('questions')
            .where('topicId', isEqualTo: topicId)
            .get();
        
        List<String> topicQuestionIds = query.docs.map((doc) => doc.id).toList();

        if (topicQuestionIds.isEmpty) continue;

        // B. Shuffle (Fentna)
        topicQuestionIds.shuffle(Random());

        // C. Cut List (Jitne user ne mange utne hi lo)
        int actualCount = requestedCount;
        if (topicQuestionIds.length < actualCount) {
          actualCount = topicQuestionIds.length; // Agar database me sawal kam hain
        }
        
        List<String> selectedIds = topicQuestionIds.sublist(0, actualCount);

        // D. Fetch Full Data for these IDs
        // (Future.wait se parallel download hoga)
        await Future.wait(selectedIds.map((id) async {
          final doc = await FirebaseFirestore.instance.collection('questions').doc(id).get();
          if (doc.exists) {
            finalQuestionsList.add(Question.fromFirestore(doc));
          }
        }));
      }

      if (finalQuestionsList.isEmpty) {
        throw "Could not generate test. No questions found.";
      }

      // 3. Final Shuffle (Taaki topics mix ho jayein, line se na aayein)
      finalQuestionsList.shuffle(Random());

      if (mounted) {
        setState(() => _isLoading = false);
        
        AdManager.showInterstitialAd(() {
          if (mounted) {
            context.push('/practice-mcq', extra: {
              'questions': finalQuestionsList,
              'topicName': 'Custom Challenge ($_totalQuestions Q)',
              'mode': 'test', 
            });
          }
        });
      }

    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Helper to update count safely
  void _updateCount(String topicId, int delta) {
    setState(() {
      int current = _topicCounts[topicId] ?? 0;
      int newVal = current + delta;
      
      // Limit check (0 se kam nahi, Total 100 se jyada nahi)
      if (newVal < 0) newVal = 0;
      
      // Agar total 100 ho chuka hai aur hum aur badha rahe hain to roko
      if (delta > 0 && _totalQuestions >= 100) {
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text("Total limit reached (100 Qs)"), duration: Duration(milliseconds: 500)),
        );
        return;
      }

      if (newVal == 0) {
        _topicCounts.remove(topicId); // Map se hata do taaki memory bache
      } else {
        _topicCounts[topicId] = newVal;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Custom Test Maker 🛠️")),
      bottomNavigationBar: _buildBottomBar(), // Generate Button niche fix kar diya
      body: Column(
        children: [
           Container(
             padding: const EdgeInsets.all(12),
             color: Colors.deepPurple.shade50,
             child: const Row(
               children: [
                 Icon(Icons.info_outline, size: 16, color: Colors.deepPurple),
                 SizedBox(width: 8),
                 Expanded(child: Text("Expand subjects and add questions from specific topics.", style: TextStyle(fontSize: 12))),
               ],
             ),
           ),
           Expanded(
             child: StreamBuilder<QuerySnapshot>(
              stream: _getSubjects(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final subjects = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: subjects.length,
                  padding: const EdgeInsets.only(bottom: 100), // Bottom bar ke liye jagah
                  itemBuilder: (context, index) {
                    final subjectDoc = subjects[index];
                    final data = subjectDoc.data() as Map<String, dynamic>;
                    final subjectName = data['subjectName'] ?? data['name'] ?? 'Subject';

                    // ✅ EXPANSION TILE (Multiple Subject Selection Logic)
                    return ExpansionTile(
                      title: Text(subjectName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      leading: const Icon(Icons.library_books, color: Colors.deepPurple),
                      children: [
                        // Inner Stream for Topics
                        _buildTopicsList(subjectDoc.id),
                      ],
                    );
                  },
                );
              },
            ),
           ),
        ],
      ),
    );
  }

  Widget _buildTopicsList(String subjectId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getTopics(subjectId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator());
        
        final topics = snapshot.data!.docs;
        if (topics.isEmpty) return const ListTile(title: Text("No topics found"));

        return Column(
          children: topics.map((topicDoc) {
            final tData = topicDoc.data() as Map<String, dynamic>;
            final topicName = tData['topicName'] ?? tData['name'] ?? 'Topic';
            final topicId = topicDoc.id;
            
            final int currentCount = _topicCounts[topicId] ?? 0;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: currentCount > 0 ? Colors.green.shade50 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: currentCount > 0 ? Colors.green : Colors.grey.shade300),
              ),
              child: ListTile(
                dense: true,
                title: Text(topicName, style: const TextStyle(fontWeight: FontWeight.w500)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // MINUS BUTTON
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      color: Colors.red,
                      onPressed: () => _updateCount(topicId, -1),
                    ),
                    
                    // COUNT DISPLAY
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300)
                      ),
                      child: Text(
                        "$currentCount", 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                      ),
                    ),

                    // PLUS BUTTON
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      color: Colors.green,
                      onPressed: () => _updateCount(topicId, 5), // +5 karega direct
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Total Qs", style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text(
                  "$_totalQuestions / 100", 
                  style: TextStyle(
                    fontSize: 20, 
                    fontWeight: FontWeight.bold, 
                    color: _totalQuestions > 100 ? Colors.red : Colors.black
                  )
                ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isLoading ? null : _generateTest,
                child: _isLoading 
                   ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                   : const Text("GENERATE TEST 🚀", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
