import 'dart:async';
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
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadRewardedAd();
  }

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/5224354917', 
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isAdLoaded = true;
        },
        onAdFailedToLoad: (LoadAdError error) {
          _rewardedAd = null;
          _isAdLoaded = false;
        },
      ),
    );
  }

  // 🔥 GENERATE TEST LOGIC
  Future<void> _generateTest() async {
    if (_totalQuestions == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select at least 1 question.")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      List<Question> finalQuestionsList = [];

      for (var entry in _topicCounts.entries) {
        String topicId = entry.key;
        int countNeeded = entry.value;
        if (countNeeded <= 0) continue;

        String randomAutoId = FirebaseFirestore.instance.collection('questions').doc().id;

        var query = await FirebaseFirestore.instance
            .collection('questions')
            .where('topicId', isEqualTo: topicId)
            .orderBy(FieldPath.documentId)
            .startAt([randomAutoId])
            .limit(countNeeded)
            .get();

        List<QueryDocumentSnapshot> docs = query.docs;

        if (docs.length < countNeeded) {
          int remaining = countNeeded - docs.length;
          var startQuery = await FirebaseFirestore.instance
              .collection('questions')
              .where('topicId', isEqualTo: topicId)
              .orderBy(FieldPath.documentId)
              .limit(remaining)
              .get();
          docs.addAll(startQuery.docs);
        }

        for (var doc in docs) {
          finalQuestionsList.add(Question.fromFirestore(doc));
        }
      }

      if (finalQuestionsList.isEmpty) {
        throw "No questions found.";
      }

      finalQuestionsList.shuffle(Random());
      
      setState(() => _isLoading = false);

      if (_rewardedAd != null && _isAdLoaded) {
        _rewardedAd!.show(
          onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
            _navigateToSuccess(finalQuestionsList);
          }
        );
        _rewardedAd = null;
        _isAdLoaded = false;
        _loadRewardedAd();
      } else {
        _navigateToSuccess(finalQuestionsList);
      }

    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        String errorMsg = e.toString();
        if (errorMsg.contains("requires an index")) {
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
        title: const Text("⚠️ Index Required"),
        content: const Text("Firebase Index missing. Check logs."),
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
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Limit 100 reached!"), duration: Duration(milliseconds: 500)));
         return;
      }
      if (newVal == 0) _topicCounts.remove(topicId);
      else _topicCounts[topicId] = newVal;
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
                 Expanded(child: Text("Select Subject -> Select Topics", style: TextStyle(fontSize: 12))),
               ],
             ),
           ),
           
           // ✅ DIRECT FIREBASE STREAM FOR SUBJECTS
           Expanded(
             child: StreamBuilder<QuerySnapshot>(
               stream: FirebaseFirestore.instance.collection('subjects').snapshots(),
               builder: (context, snapshot) {
                 // 1. Loading State
                 if (snapshot.connectionState == ConnectionState.waiting) {
                   return const Center(child: CircularProgressIndicator());
                 }
                 
                 // 2. Error State (YAHAN PATA CHALEGA AGAR ERROR HAI)
                 if (snapshot.hasError) {
                   return Center(
                     child: Padding(
                       padding: const EdgeInsets.all(16.0),
                       child: Text(
                         "Error loading subjects:\n${snapshot.error}",
                         style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                         textAlign: TextAlign.center,
                       ),
                     ),
                   );
                 }

                 // 3. Empty State
                 if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                   return const Center(child: Text("No subjects found in Database."));
                 }

                 final subjects = snapshot.data!.docs;

                 return ListView.builder(
                   itemCount: subjects.length,
                   padding: const EdgeInsets.only(bottom: 20),
                   itemBuilder: (context, index) {
                     final sDoc = subjects[index];
                     final sData = sDoc.data() as Map<String, dynamic>;
                     
                     // ✅ Name Handling (Safety)
                     final sName = sData['subjectName'] ?? sData['name'] ?? 'Unnamed Subject';
                     
                     return ExpansionTile(
                       title: Text(sName, style: const TextStyle(fontWeight: FontWeight.bold)),
                       leading: const Icon(Icons.library_books, color: Colors.deepPurple),
                       children: [
                         // Nested Stream for Topics
                         _buildTopicsList(sDoc.id),
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

  // Helper Widget for Topics Stream
  Widget _buildTopicsList(String subjectId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('topics')
          .where('subjectId', isEqualTo: subjectId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Text("Error loading topics", style: TextStyle(color: Colors.red));
        if (snapshot.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator());
        
        final topics = snapshot.data!.docs;
        if (topics.isEmpty) return const ListTile(title: Text("No topics found"));

        return Column(
          children: topics.map((tDoc) {
            final tData = tDoc.data() as Map<String, dynamic>;
            // ✅ Name Handling (Safety)
            final tName = tData['topicName'] ?? tData['name'] ?? 'Unnamed Topic';
            final tId = tDoc.id;
            final int count = _topicCounts[tId] ?? 0;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: count > 0 ? Colors.green.shade50 : Colors.grey.shade50, 
                borderRadius: BorderRadius.circular(10), 
                border: Border.all(color: count > 0 ? Colors.green : Colors.grey.shade300)
              ),
              child: ListTile(
                dense: true,
                title: Text(tName, style: const TextStyle(fontWeight: FontWeight.w500)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red), 
                      onPressed: () => _updateCount(tId, -1)
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                      child: Text("$count", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: Colors.green), 
                      onPressed: () => _updateCount(tId, 5)
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
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Total Qs", style: TextStyle(fontSize: 12, color: Colors.grey)), Text("$_totalQuestions / 100", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]),
            const SizedBox(width: 20),
            Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: _isLoading ? null : _generateTest, child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("GENERATE TEST 🚀", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))),
          ],
        ),
      ),
    );
  }
}
