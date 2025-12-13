import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'; 
import 'package:exambeing/models/question_model.dart';
import 'package:exambeing/features/tests/screens/test_success_screen.dart';

class TestGeneratorScreen extends StatefulWidget {
  const TestGeneratorScreen({super.key});

  @override
  State<TestGeneratorScreen> createState() => _TestGeneratorScreenState();
}

class _TestGeneratorScreenState extends State<TestGeneratorScreen> {
  final Map<String, int> _topicCounts = {};
  int get _totalQuestions => _topicCounts.values.fold(0, (sum, count) => sum + count);
  
  bool _isLoading = false;
  RewardedAd? _rewardedAd; 

  @override
  void initState() {
    super.initState();
    _loadRewardedAd();
  }

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: 'ca-app-pub-1310160958851625/4433600767', 
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
        },
        onAdFailedToLoad: (LoadAdError error) {
          _rewardedAd = null;
        },
      ),
    );
  }

  Stream<QuerySnapshot> _getSubjects() {
    return FirebaseFirestore.instance.collection('subjects').snapshots();
  }

  Stream<QuerySnapshot> _getTopics(String subjectId) {
    return FirebaseFirestore.instance
        .collection('topics')
        .where('subjectId', isEqualTo: subjectId)
        .snapshots();
  }

  // 🔥 TRUE RANDOM + LOW READS STRATEGY
  Future<void> _generateTest() async {
    if (_totalQuestions == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one question!"))
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      List<Question> finalQuestionsList = [];
      final Random random = Random();

      // Har Topic ke liye loop chalayenge
      for (var entry in _topicCounts.entries) {
        String topicId = entry.key;
        int countNeeded = entry.value;

        if (countNeeded <= 0) continue;

        // 🧠 Strategy: Ek baar me 10 lene ki jagah, 
        // hum 10 alag-alag random points se 1-1 sawal uthayenge.
        // Isse sawal repeat hone ka chance khatam ho jayega aur Reads bhi utne hi rahenge.

        List<Future<void>> fetchTasks = [];

        for (int i = 0; i < countNeeded; i++) {
          fetchTasks.add(Future(() async {
            // 1. Generate Random ID
            String randomAutoId = FirebaseFirestore.instance.collection('questions').doc().id;

            // 2. Try fetching 1 question AFTER random ID
            var query = await FirebaseFirestore.instance
                .collection('questions')
                .where('topicId', isEqualTo: topicId)
                .orderBy(FieldPath.documentId)
                .startAt([randomAutoId])
                .limit(1) // Sirf 1 sawal (1 Read)
                .get();

            if (query.docs.isNotEmpty) {
              finalQuestionsList.add(Question.fromFirestore(query.docs.first));
            } else {
              // Agar Random ID sabse last me chali gayi aur kuch nahi mila,
              // To shuruwat se 1 utha lo (Wrap around)
              var startQuery = await FirebaseFirestore.instance
                  .collection('questions')
                  .where('topicId', isEqualTo: topicId)
                  .orderBy(FieldPath.documentId)
                  .limit(1)
                  .get();
              
              if (startQuery.docs.isNotEmpty) {
                finalQuestionsList.add(Question.fromFirestore(startQuery.docs.first));
              }
            }
          }));
        }

        // Saare calls ek sath parallel me bhejo (Fast)
        await Future.wait(fetchTasks);
      }

      // Remove Duplicates (Agar kismat se same sawal 2 baar aa gaya ho)
      final uniqueIds = <String>{};
      finalQuestionsList.retainWhere((q) => uniqueIds.add(q.id));

      if (finalQuestionsList.isEmpty) {
        throw "No questions found.";
      }

      // Final Shuffle
      finalQuestionsList.shuffle(Random());

      setState(() => _isLoading = false);

      if (_rewardedAd != null) {
        _rewardedAd!.show(
          onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
            _navigateToSuccess(finalQuestionsList);
          }
        );
        _rewardedAd = null;
        _loadRewardedAd(); 
      } else {
        _navigateToSuccess(finalQuestionsList);
      }

    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        if (e.toString().contains("requires an index")) {
           _showIndexErrorDialog();
        } else {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
           );
        }
      }
    }
  }

  void _showIndexErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("⚠️ Database Setup Required"),
        content: const Text(
          "For this random feature to work, you need an Index.\n\n"
          "1. Check Debug Console for the link.\n"
          "2. Click Create Index in Firebase Console."
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
      ),
    );
  }

  void _navigateToSuccess(List<Question> questions) {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TestSuccessScreen(
          questions: questions,
          topicName: 'Custom Challenge ($_totalQuestions Q)',
        ),
      ),
    );
  }

  void _updateCount(String topicId, int delta) {
    setState(() {
      int current = _topicCounts[topicId] ?? 0;
      int newVal = max(0, current + delta);
      
      if (delta > 0 && _totalQuestions >= 100) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text("Max limit 100 questions reached!"), duration: Duration(milliseconds: 500))
         );
         return;
      }

      if (newVal == 0) {
        _topicCounts.remove(topicId);
      } else {
        _topicCounts[topicId] = newVal;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Custom Test Maker 🛠️")),
      bottomNavigationBar: _buildBottomBar(),
      body: Column(
        children: [
           Container(
             padding: const EdgeInsets.all(12),
             color: Colors.deepPurple.shade50,
             child: const Row(
               children: [
                 Icon(Icons.info_outline, size: 16, color: Colors.deepPurple),
                 SizedBox(width: 8),
                 Expanded(child: Text("Expand subjects and select question count for topics.", style: TextStyle(fontSize: 12))),
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
                  padding: const EdgeInsets.only(bottom: 100),
                  itemBuilder: (context, index) {
                    final subjectDoc = subjects[index];
                    final data = subjectDoc.data() as Map<String, dynamic>;
                    
                    final subjectName = data['subjectName'] ?? data['name'] ?? 'Subject';

                    return ExpansionTile(
                      title: Text(subjectName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      leading: const Icon(Icons.library_books, color: Colors.deepPurple),
                      children: [
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
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      color: Colors.red,
                      onPressed: () => _updateCount(topicId, -1),
                    ),
                    
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

                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      color: Colors.green,
                      onPressed: () => _updateCount(topicId, 5),
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
