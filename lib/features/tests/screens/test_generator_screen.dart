import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:exambeing/models/question_model.dart';
import 'package:exambeing/features/tests/screens/test_success_screen.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Added for tracking daily limit

class TestGeneratorScreen extends StatefulWidget {
  const TestGeneratorScreen({super.key});

  @override
  State<TestGeneratorScreen> createState() => _TestGeneratorScreenState();
}

class _TestGeneratorScreenState extends State<TestGeneratorScreen> {
  final Map<String, int> _topicCounts = {};
  
  // Getter for total questions
  int get _totalQuestions => _topicCounts.values.fold(0, (sum, count) => sum + count);
  
  bool _isLoading = false;
  RewardedAd? _rewardedAd; 

  // --- ADMIN & LIMIT VARIABLES ---
  bool _isAdmin = false; 
  int _maxQuestionsLimit = 25; // Default for normal users
  final int _adminLimit = 200; // Limit for Admin
  final int _dailyTestLimit = 3; // Max tests per day for normal users

  @override
  void initState() {
    super.initState();
    _checkUserStatus(); 
    _loadRewardedAd();
  }

  // --- 0. CHECK USER STATUS (ADMIN CHECK) ---
  Future<void> _checkUserStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (user.email == "opsiddh42@gmail.com") {
        setState(() {
          _isAdmin = true;
          _maxQuestionsLimit = _adminLimit;
        });
      }
    }
  }

  // --- 1. ADMOB LOGIC ---
  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/5224354917', // Test ID
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

  // --- 2. FIREBASE STREAMS ---
  Stream<QuerySnapshot> _getSubjects() {
    return FirebaseFirestore.instance.collection('subjects').snapshots();
  }

  Stream<QuerySnapshot> _getTopics(String subjectId) {
    return FirebaseFirestore.instance
        .collection('topics')
        .where('subjectId', isEqualTo: subjectId)
        .snapshots();
  }

  // --- 3. DAILY LIMIT CHECK LOGIC ---
  Future<bool> _canGenerateTest() async {
    if (_isAdmin) return true; // Admins have no daily limit

    final prefs = await SharedPreferences.getInstance();
    final String todayKey = "test_gen_${DateTime.now().toIso8601String().split('T')[0]}"; // Key like test_gen_2023-10-27
    int testsGeneratedToday = prefs.getInt(todayKey) ?? 0;

    if (testsGeneratedToday >= _dailyTestLimit) {
      _showDailyLimitReachedDialog();
      return false;
    }
    return true;
  }

  Future<void> _incrementTestCount() async {
    if (_isAdmin) return;

    final prefs = await SharedPreferences.getInstance();
    final String todayKey = "test_gen_${DateTime.now().toIso8601String().split('T')[0]}";
    int testsGeneratedToday = prefs.getInt(todayKey) ?? 0;
    await prefs.setInt(todayKey, testsGeneratedToday + 1);
  }

  // --- 4. POPUPS ---
  void _showDailyLimitReachedDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          contentPadding: const EdgeInsets.all(20),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.hourglass_empty_rounded, size: 40, color: Colors.orange),
              ),
              const SizedBox(height: 20),
              const Text(
                "Daily Limit Reached",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 10),
              const Text(
                "You have generated 3 tests today. Please come back after 24 hours to generate more tests.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Got it"),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- 5. COUNTER UPDATE LOGIC ---
  void _updateCount(String topicId, int delta) {
    int current = _topicCounts[topicId] ?? 0;
    
    // Check if adding exceeds limit
    if (delta > 0) {
      if (_totalQuestions + delta > _maxQuestionsLimit) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: Text("Maximum limit is $_maxQuestionsLimit questions."),
             duration: const Duration(seconds: 2),
           )
        );
        return; 
      }
    }

    setState(() {
      int newVal = max(0, current + delta);
      if (newVal == 0) {
        _topicCounts.remove(topicId);
      } else {
        _topicCounts[topicId] = newVal;
      }
    });
  }

  // --- 6. GENERATE FUNCTION ---
  Future<void> _generateTest() async {
    // 1. Basic Validation
    if (_totalQuestions == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one question!"))
      );
      return;
    }

    // 2. Max Questions Limit Check (Safety)
    if (_totalQuestions > _maxQuestionsLimit) {
       ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("Maximum limit is $_maxQuestionsLimit questions."))
       );
       return;
    }

    // 3. Check Daily Limit
    bool canProceed = await _canGenerateTest();
    if (!canProceed) return;

    setState(() => _isLoading = true);

    try {
      List<Question> finalQuestionsList = [];
      final collectionRef = FirebaseFirestore.instance.collection('questions');

      for (var entry in _topicCounts.entries) {
        String topicId = entry.key;
        int countNeeded = entry.value;

        if (countNeeded <= 0) continue;

        String randomAutoId = collectionRef.doc().id;

        var querySnapshot = await collectionRef
            .where('topicId', isEqualTo: topicId)
            .orderBy(FieldPath.documentId)
            .startAt([randomAutoId])
            .limit(countNeeded)
            .get();

        List<DocumentSnapshot> docs = querySnapshot.docs.toList();

        if (docs.length < countNeeded) {
          int remaining = countNeeded - docs.length;
          var startQuery = await collectionRef
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

      final uniqueIds = <String>{};
      finalQuestionsList.retainWhere((q) => uniqueIds.add(q.id));

      if (finalQuestionsList.isEmpty) {
        throw "No questions found. Try selecting different topics.";
      }

      finalQuestionsList.shuffle();

      // Update Daily Count Here
      await _incrementTestCount();

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
        content: const Text("Firebase needs an Index for random selection logic."),
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

  // --- 7. UI BUILD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Custom Test Maker 🛠️"),
        actions: [
          if (_isAdmin)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Icon(Icons.admin_panel_settings, color: Colors.redAccent),
            )
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
      body: Column(
        children: [
           Container(
             padding: const EdgeInsets.all(12),
             color: _isAdmin ? Colors.red.shade50 : Colors.blue.shade50,
             child: Row(
               children: [
                 Icon(
                   _isAdmin ? Icons.shield : Icons.info, 
                   size: 16, 
                   color: _isAdmin ? Colors.red : Colors.blue
                 ),
                 const SizedBox(width: 8),
                 Expanded(
                   child: Text(
                     _isAdmin 
                       ? "Admin Mode: Limit 200 Questions. No Daily Limit." 
                       : "Daily Limit: 3 Tests/Day. Max 25 Questions per test.", 
                     style: TextStyle(
                       fontSize: 12, 
                       color: Colors.black87,
                       fontWeight: FontWeight.w500
                     )
                   )
                 ),
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
                      onPressed: () => _updateCount(topicId, -5),
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
                  "$_totalQuestions / $_maxQuestionsLimit", 
                  style: TextStyle(
                    fontSize: 20, 
                    fontWeight: FontWeight.bold, 
                    color: _totalQuestions >= _maxQuestionsLimit ? Colors.orange : Colors.black
                  )
                ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isAdmin ? Colors.redAccent : Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isLoading ? null : _generateTest,
                child: _isLoading 
                   ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                   : Text(_isAdmin ? "GENERATE ADMIN TEST 🛡️" : "GENERATE TEST 🚀", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
