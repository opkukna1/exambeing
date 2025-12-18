import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// अपने प्रोजेक्ट के हिसाब से ये इंपोर्ट चेक कर लेना
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

  @override
  void initState() {
    super.initState();
    _loadRewardedAd();
  }

  // --- 1. ADMOB LOGIC ---
  void _loadRewardedAd() {
    RewardedAd.load(
      // TEST ID है, पब्लिश करते समय अपनी असली ID डालना
      adUnitId: 'ca-app-pub-3940256099942544/5224354917', 
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

  // --- 3. 🔥 MAIN GENERATE FUNCTION (OPTIMIZED) ---
  Future<void> _generateTest() async {
    // अगर 0 सवाल हैं तो रोक दो
    if (_totalQuestions == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one question!"))
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      List<Question> finalQuestionsList = [];
      final collectionRef = FirebaseFirestore.instance.collection('questions');

      // हर सेलेक्ट किए गए टॉपिक के लिए लूप
      for (var entry in _topicCounts.entries) {
        String topicId = entry.key;
        int countNeeded = entry.value;

        if (countNeeded <= 0) continue;

        // --- SMART STRATEGY (BATCH FETCH) ---
        
        // A. एक रैंडम ID जनरेट करो
        String randomAutoId = collectionRef.doc().id;

        // B. रैंडम ID के बाद वाले सवाल एक साथ उठाओ (सिर्फ 1 Read में)
        var querySnapshot = await collectionRef
            .where('topicId', isEqualTo: topicId)
            .orderBy(FieldPath.documentId) // ID से सॉर्ट जरूरी है
            .startAt([randomAutoId])       // रैंडम जगह से शुरू
            .limit(countNeeded)            // जितने चाहिए उतने एक बार में
            .get();

        List<DocumentSnapshot> docs = querySnapshot.docs.toList();

        // C. अगर लिस्ट के अंत में थे और कम सवाल मिले, तो शुरू से बाकी उठा लो
        if (docs.length < countNeeded) {
          int remaining = countNeeded - docs.length;
          
          var startQuery = await collectionRef
              .where('topicId', isEqualTo: topicId)
              .orderBy(FieldPath.documentId)
              .limit(remaining)
              .get();
          
          docs.addAll(startQuery.docs);
        }

        // D. मॉडल में कन्वर्ट करो और लिस्ट में डालो
        for (var doc in docs) {
          finalQuestionsList.add(Question.fromFirestore(doc));
        }
      }

      // डुप्लीकेट हटाओ (सेफ्टी के लिए)
      final uniqueIds = <String>{};
      finalQuestionsList.retainWhere((q) => uniqueIds.add(q.id));

      if (finalQuestionsList.isEmpty) {
        throw "No questions found. Try selecting different topics.";
      }

      // लिस्ट को शफल करो ताकि मिक्स हो जाए
      finalQuestionsList.shuffle();

      setState(() => _isLoading = false);

      // --- ADS & NAVIGATION ---
      if (_rewardedAd != null) {
        _rewardedAd!.show(
          onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
            _navigateToSuccess(finalQuestionsList);
          }
        );
        _rewardedAd = null;
        _loadRewardedAd(); // अगली बार के लिए लोड करो
      } else {
        _navigateToSuccess(finalQuestionsList);
      }

    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // इंडेक्स एरर हैंडलिंग
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
          "For this random feature to work, Firebase needs an Index.\n\n"
          "1. Check the 'Run' or 'Debug' tab in your IDE.\n"
          "2. Click the link generated by Firebase to create the index automatically."
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

  // --- 4. COUNTER UPDATE LOGIC ---
  void _updateCount(String topicId, int delta) {
    setState(() {
      int current = _topicCounts[topicId] ?? 0;
      int newVal = max(0, current + delta);
      
      // मैक्सिमम 100 सवाल की लिमिट
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

  // --- 5. UI BUILD ---
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
                      onPressed: () => _updateCount(topicId, -5), // -5 किया है
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
                      onPressed: () => _updateCount(topicId, 5), // +5 किया है
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
