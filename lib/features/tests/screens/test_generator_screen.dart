import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard ke liye
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // User Check ke liye
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
  
  // टोटल सवाल गिनने का getter
  int get _totalQuestions => _topicCounts.values.fold(0, (sum, count) => sum + count);
  
  bool _isLoading = false;
  RewardedAd? _rewardedAd; 

  // --- PREMIUM LOGIC VARIABLES ---
  bool _isPremium = false; // Default Free
  int _maxQuestionsLimit = 25; // Default Limit for Free Users

  @override
  void initState() {
    super.initState();
    _checkSubscriptionStatus(); // Check User Status
    _loadRewardedAd();
  }

  // --- 0. CHECK SUBSCRIPTION STATUS ---
  Future<void> _checkSubscriptionStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data();
          // Check if field exists and equals 'yes'
          if (data != null && data['paid_for_gold'] == 'yes') {
            setState(() {
              _isPremium = true;
              _maxQuestionsLimit = 200; // Premium Limit
            });
          }
        }
      } catch (e) {
        debugPrint("Error checking subscription: $e");
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

  // --- 3. SHOW PREMIUM POPUP ---
  void _showPremiumDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Row(
            children: [
              Icon(Icons.workspace_premium, color: Colors.amber, size: 28),
              SizedBox(width: 10),
              Text("Upgrade Required"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Free users can generate tests up to 25 questions only.",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              const Text(
                "To unlock 200 Questions Limit, Subscribe Now!",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green)
                ),
                child: Column(
                  children: [
                    const Text("Contact Exambeing Team via WhatsApp:", style: TextStyle(fontSize: 12)),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "8005576670",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, color: Colors.green),
                          onPressed: () {
                            Clipboard.setData(const ClipboardData(text: "8005576670"));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Number Copied!"), duration: Duration(seconds: 1)),
                            );
                          },
                        )
                      ],
                    ),
                  ],
                ),
              )
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  // --- 4. COUNTER UPDATE LOGIC (MODIFIED) ---
  void _updateCount(String topicId, int delta) {
    int current = _topicCounts[topicId] ?? 0;
    
    // अगर हम जोड़ रहे हैं (Positive Delta)
    if (delta > 0) {
      // चेक करो कि क्या लिमिट पार हो रही है
      if (_totalQuestions + delta > _maxQuestionsLimit) {
        if (!_isPremium) {
          // अगर फ्री यूजर है और 25 से ऊपर जा रहा है -> POPUP दिखाओ
          _showPremiumDialog();
        } else {
          // अगर प्रीमियम यूजर है और 200 से ऊपर जा रहा है -> SNACKBAR दिखाओ
          ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text("Maximum limit of 200 questions reached!"))
          );
        }
        return; // आगे मत बढ़ो
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

  // --- 5. GENERATE FUNCTION ---
  Future<void> _generateTest() async {
    if (_totalQuestions == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one question!"))
      );
      return;
    }

    // Double Check Limit (Safety)
    if (_totalQuestions > _maxQuestionsLimit) {
       if(!_isPremium) _showPremiumDialog();
       return;
    }

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

  // --- 6. UI BUILD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Custom Test Maker 🛠️"),
        actions: [
          // Premium Badge in AppBar
          if (_isPremium)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Icon(Icons.verified, color: Colors.amber),
            )
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
      body: Column(
        children: [
           Container(
             padding: const EdgeInsets.all(12),
             color: _isPremium ? Colors.amber.shade50 : Colors.deepPurple.shade50,
             child: Row(
               children: [
                 Icon(
                   _isPremium ? Icons.star : Icons.info_outline, 
                   size: 16, 
                   color: _isPremium ? Colors.amber[800] : Colors.deepPurple
                 ),
                 const SizedBox(width: 8),
                 Expanded(
                   child: Text(
                     _isPremium 
                       ? "Premium Unlocked! You can create tests up to 200 Questions." 
                       : "Free Limit: 25 Questions. Upgrade for more.", 
                     style: TextStyle(
                       fontSize: 12, 
                       color: _isPremium ? Colors.brown : Colors.black87,
                       fontWeight: _isPremium ? FontWeight.bold : FontWeight.normal
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
                // LIMIT Display Dynamic hai ab
                Text(
                  "$_totalQuestions / $_maxQuestionsLimit", 
                  style: TextStyle(
                    fontSize: 20, 
                    fontWeight: FontWeight.bold, 
                    color: _totalQuestions == _maxQuestionsLimit ? Colors.orange : Colors.black
                  )
                ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isPremium ? Colors.amber[800] : Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isLoading ? null : _generateTest,
                child: _isLoading 
                   ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                   : Text(_isPremium ? "GENERATE GOLD TEST 🏆" : "GENERATE TEST 🚀", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
