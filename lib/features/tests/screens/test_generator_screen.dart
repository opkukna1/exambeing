import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:exambeing/models/question_model.dart';
import 'package:exambeing/features/tests/screens/test_success_screen.dart';

class TestGeneratorScreen extends StatefulWidget {
  const TestGeneratorScreen({super.key});

  @override
  State<TestGeneratorScreen> createState() => _TestGeneratorScreenState();
}

class _TestGeneratorScreenState extends State<TestGeneratorScreen> {
  // Store selected counts: {'topicId': 5, 'anotherTopicId': 10}
  final Map<String, int> _topicCounts = {};
  int get _totalQuestions => _topicCounts.values.fold(0, (sum, count) => sum + count);
  
  bool _isLoading = false;
  bool _isDataLoading = true; // For initial cache load
  
  // Ad Variables
  RewardedAd? _rewardedAd; 
  bool _isAdLoaded = false;

  // Local Cache Lists
  List<Map<String, dynamic>> _cachedSubjects = [];
  List<Map<String, dynamic>> _cachedTopics = [];

  @override
  void initState() {
    super.initState();
    _loadRewardedAd();
    _loadDataWithCache(); // Load Subjects & Topics
  }

  // 📺 1. LOAD REWARDED AD
  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/5224354917', // Test ID
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint("✅ Ad Loaded");
          _rewardedAd = ad;
          _isAdLoaded = true;
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint("❌ Ad Failed: $error");
          _rewardedAd = null;
          _isAdLoaded = false;
        },
      ),
    );
  }

  // 💾 2. CACHING LOGIC (Saves Reads)
  Future<void> _loadDataWithCache() async {
    final prefs = await SharedPreferences.getInstance();
    final int? lastFetchTime = prefs.getInt('last_metadata_fetch');
    final DateTime now = DateTime.now();
    
    bool shouldFetchFromFirebase = true;

    // Check if cache is fresh (< 12 hours)
    if (lastFetchTime != null) {
      final lastDate = DateTime.fromMillisecondsSinceEpoch(lastFetchTime);
      if (now.difference(lastDate).inHours < 12) {
        shouldFetchFromFirebase = false;
      }
    }

    if (shouldFetchFromFirebase) {
      // 🌍 Fetch form Firebase
      try {
        // Subjects
        final subSnapshot = await FirebaseFirestore.instance.collection('subjects').get();
        List<Map<String, dynamic>> subs = subSnapshot.docs.map((doc) {
          final d = doc.data(); d['id'] = doc.id; return d;
        }).toList();

        // Topics
        final topSnapshot = await FirebaseFirestore.instance.collection('topics').get();
        List<Map<String, dynamic>> tops = topSnapshot.docs.map((doc) {
          final d = doc.data(); d['id'] = doc.id; return d;
        }).toList();

        // Save to Local
        await prefs.setString('cached_subjects', jsonEncode(subs));
        await prefs.setString('cached_topics', jsonEncode(tops));
        await prefs.setInt('last_metadata_fetch', now.millisecondsSinceEpoch);

        if (mounted) setState(() { _cachedSubjects = subs; _cachedTopics = tops; _isDataLoading = false; });
      } catch (e) {
        _loadFromLocal(prefs); // Fallback
      }
    } else {
      // 🏠 Load from Local
      _loadFromLocal(prefs);
    }
  }

  void _loadFromLocal(SharedPreferences prefs) {
    String? subStr = prefs.getString('cached_subjects');
    String? topStr = prefs.getString('cached_topics');

    if (subStr != null && topStr != null) {
      if (mounted) {
        setState(() {
          _cachedSubjects = List<Map<String, dynamic>>.from(jsonDecode(subStr));
          _cachedTopics = List<Map<String, dynamic>>.from(jsonDecode(topStr));
          _isDataLoading = false;
        });
      }
    } else {
      // First run or cleared cache
      prefs.remove('last_metadata_fetch');
      _loadDataWithCache(); // Force fetch
    }
  }

  // 🔥 3. GENERATE TEST (SUPER FAST BATCH LOGIC)
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

        // 🧠 Logic: Generate Random ID and fetch 'N' questions after it.
        // Single DB call per topic. Very Fast.
        String randomAutoId = FirebaseFirestore.instance.collection('questions').doc().id;

        // Try fetching
        var query = await FirebaseFirestore.instance
            .collection('questions')
            .where('topicId', isEqualTo: topicId)
            .orderBy(FieldPath.documentId)
            .startAt([randomAutoId])
            .limit(countNeeded)
            .get();

        List<QueryDocumentSnapshot> docs = query.docs;

        // Wrap-around logic: If random start was near end, fetch remaining from start
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
        throw "No questions found in selected topics.";
      }

      finalQuestionsList.shuffle(Random());
      
      // Stop Loading
      setState(() => _isLoading = false);

      // 4. SHOW AD OR NAVIGATE
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
        debugPrint("⚠️ Ad not ready, skipping...");
        _navigateToSuccess(finalQuestionsList);
      }

    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        String errorMsg = e.toString();
        
        // 🚨 INDEX ERROR HANDLING
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
        content: const Text(
          "For this feature to work, Firebase needs an Index.\n\n"
          "1. Check your Debug Console logs.\n"
          "2. Click the link (https://console.firebase...).\n"
          "3. Create Index and wait 2 mins."
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

  // Counter Helper
  void _updateCount(String topicId, int delta) {
    setState(() {
      int current = _topicCounts[topicId] ?? 0;
      int newVal = max(0, current + delta);
      if (delta > 0 && _totalQuestions >= 100) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Max limit 100 questions reached!"), duration: Duration(milliseconds: 500)));
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
                 Expanded(child: Text("Expand subjects -> Add questions -> Generate", style: TextStyle(fontSize: 12))),
               ],
             ),
           ),
           Expanded(
             child: _isDataLoading 
               ? const Center(child: CircularProgressIndicator()) 
               : ListView.builder(
                  itemCount: _cachedSubjects.length,
                  padding: const EdgeInsets.only(bottom: 100),
                  itemBuilder: (context, index) {
                    final sData = _cachedSubjects[index];
                    // Name Fallback
                    final sName = sData['subjectName'] ?? sData['name'] ?? 'Subject';
                    final sId = sData['id'];
                    
                    // Filter Topics for this Subject
                    final rTopics = _cachedTopics.where((t) => t['subjectId'] == sId).toList();

                    if (rTopics.isEmpty) return const SizedBox.shrink();

                    return ExpansionTile(
                      title: Text(sName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      leading: const Icon(Icons.library_books, color: Colors.deepPurple),
                      children: rTopics.map((tData) {
                        final tName = tData['topicName'] ?? tData['name'] ?? 'Topic';
                        final tId = tData['id'];
                        final int count = _topicCounts[tId] ?? 0;

                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(color: count > 0 ? Colors.green.shade50 : Colors.grey.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: count > 0 ? Colors.green : Colors.grey.shade300)),
                          child: ListTile(
                            dense: true,
                            title: Text(tName, style: const TextStyle(fontWeight: FontWeight.w500)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: () => _updateCount(tId, -1)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                                  child: Text("$count", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                ),
                                IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.green), onPressed: () => _updateCount(tId, 5)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
           ),
        ],
      ),
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
