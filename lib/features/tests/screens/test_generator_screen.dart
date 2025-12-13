import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart'; // Ya Navigator use karein
import 'package:google_mobile_ads/google_mobile_ads.dart'; // ✅ ADS
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
  RewardedAd? _rewardedAd; // ✅ Rewarded Ad Variable

  @override
  void initState() {
    super.initState();
    _loadRewardedAd(); // Screen khulte hi Ad load karo
  }

  // 📺 1. LOAD REWARDED AD
  void _loadRewardedAd() {
    RewardedAd.load(
      // Test ID use kar raha hu (Release ke waqt Real ID lagana)
      adUnitId: 'ca-app-pub-3940256099942544/5224354917', 
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('$ad loaded.');
          _rewardedAd = ad;
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('RewardedAd failed to load: $error');
          _rewardedAd = null;
        },
      ),
    );
  }

  // ... (Baki purana Stream code Subjects/Topics ka same rahega) ...
  // Me yahan sirf important parts likh raha hu taaki code lamba na ho.
  // Aapka _getSubjects aur _getTopics function waisa hi rahega.

  Stream<QuerySnapshot> _getSubjects() {
    return FirebaseFirestore.instance.collection('subjects').snapshots();
  }

  Stream<QuerySnapshot> _getTopics(String subjectId) {
    return FirebaseFirestore.instance.collection('topics').where('subjectId', isEqualTo: subjectId).snapshots();
  }

  // 🔥 2. GENERATE TEST WITH AD LOGIC
  Future<void> _generateTest() async {
    if (_totalQuestions == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select at least one question!")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // --- DATA FETCHING LOGIC (SAME AS BEFORE) ---
      List<Question> finalQuestionsList = [];
      for (var entry in _topicCounts.entries) {
        String topicId = entry.key;
        int requestedCount = entry.value;
        if (requestedCount <= 0) continue;

        final query = await FirebaseFirestore.instance.collection('questions').where('topicId', isEqualTo: topicId).get();
        List<String> topicQuestionIds = query.docs.map((doc) => doc.id).toList();
        if (topicQuestionIds.isEmpty) continue;

        topicQuestionIds.shuffle(Random());
        int actualCount = min(requestedCount, topicQuestionIds.length);
        List<String> selectedIds = topicQuestionIds.sublist(0, actualCount);

        await Future.wait(selectedIds.map((id) async {
          final doc = await FirebaseFirestore.instance.collection('questions').doc(id).get();
          if (doc.exists) finalQuestionsList.add(Question.fromFirestore(doc));
        }));
      }

      if (finalQuestionsList.isEmpty) throw "No questions found.";
      finalQuestionsList.shuffle(Random());
      // ---------------------------------------------

      setState(() => _isLoading = false);

      // ✅ 3. SHOW REWARDED AD BEFORE NAVIGATION
      if (_rewardedAd != null) {
        _rewardedAd!.show(
          onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
            // User ne Ad dekha, ab aage jane do
            _navigateToSuccess(finalQuestionsList);
          }
        );
        _rewardedAd = null; // Ad use ho gaya, null kar do
        _loadRewardedAd(); // Next time ke liye naya load karo
      } else {
        // Agar Ad load nahi hua to direct bhej do (User ko mat roko)
        _navigateToSuccess(finalQuestionsList);
      }

    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
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
      if (delta > 0 && _totalQuestions >= 100) return;
      if (newVal == 0) _topicCounts.remove(topicId);
      else _topicCounts[topicId] = newVal;
    });
  }

  @override
  Widget build(BuildContext context) {
    // UI Code same rahega jo pichle step me diya tha
    // Bas function call wahi rahegi
    return Scaffold(
      appBar: AppBar(title: const Text("Custom Test Maker 🛠️")),
      bottomNavigationBar: _buildBottomBar(),
      body: Column(
        children: [
           // ... (Header UI same) ...
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
                    // UI SAME AS BEFORE
                    return ExpansionTile(
                      title: Text(data['subjectName'] ?? 'Subject', style: const TextStyle(fontWeight: FontWeight.bold)),
                      children: [_buildTopicsList(subjectDoc.id)],
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

  // _buildTopicsList aur _buildBottomBar same rahenge (Copy paste from previous code)
  // Sirf _generateTest function change hua hai upar wala.
  
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
            final topicName = tData['topicName'] ?? 'Topic';
            final topicId = topicDoc.id;
            final int currentCount = _topicCounts[topicId] ?? 0;
            return ListTile(
                title: Text(topicName),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: () => _updateCount(topicId, -1)),
                    Text("$currentCount", style: const TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.green), onPressed: () => _updateCount(topicId, 5)),
                  ],
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
      color: Colors.white,
      child: SafeArea(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, padding: const EdgeInsets.all(15)),
          onPressed: _isLoading ? null : _generateTest,
          child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("GENERATE TEST 🚀 (Watch Ad)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
