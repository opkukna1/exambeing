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
  final Map<String, int> _topicCounts = {};
  int get _totalQuestions => _topicCounts.values.fold(0, (sum, count) => sum + count);
  
  bool _isLoading = false;
  bool _isDataLoading = true; 
  
  RewardedAd? _rewardedAd; 
  bool _isAdLoaded = false;

  List<Map<String, dynamic>> _cachedSubjects = [];
  List<Map<String, dynamic>> _cachedTopics = [];

  @override
  void initState() {
    super.initState();
    _loadRewardedAd();
    _loadDataWithCache(); 
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

  // 💾 SAFE CACHING LOGIC (Fixed JSON Error)
  Future<void> _loadDataWithCache() async {
    final prefs = await SharedPreferences.getInstance();
    final int? lastFetchTime = prefs.getInt('last_metadata_fetch');
    final DateTime now = DateTime.now();
    
    bool shouldFetchFromFirebase = true;

    // 12 Hours Cache Rule
    if (lastFetchTime != null) {
      final lastDate = DateTime.fromMillisecondsSinceEpoch(lastFetchTime);
      if (now.difference(lastDate).inHours < 12) {
        shouldFetchFromFirebase = false;
      }
    }

    if (shouldFetchFromFirebase) {
      try {
        // Fetch Subjects
        final subSnapshot = await FirebaseFirestore.instance.collection('subjects').get();
        List<Map<String, dynamic>> subs = subSnapshot.docs.map((doc) {
          final data = doc.data();
          // ✅ FIX: Sirf String data lo (Timestamp error avoid karne ke liye)
          return {
            'id': doc.id,
            'subjectName': data['subjectName'] ?? data['name'] ?? 'Subject',
          };
        }).toList();

        // Fetch Topics
        final topSnapshot = await FirebaseFirestore.instance.collection('topics').get();
        List<Map<String, dynamic>> tops = topSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'subjectId': data['subjectId'] ?? '',
            'topicName': data['topicName'] ?? data['name'] ?? 'Topic',
          };
        }).toList();

        // Save to Local
        await prefs.setString('cached_subjects', jsonEncode(subs));
        await prefs.setString('cached_topics', jsonEncode(tops));
        await prefs.setInt('last_metadata_fetch', now.millisecondsSinceEpoch);

        if (mounted) {
          setState(() { 
            _cachedSubjects = subs; 
            _cachedTopics = tops; 
            _isDataLoading = false; 
          });
        }
      } catch (e) {
        debugPrint("Error fetching data: $e");
        // Fallback to local if Firebase fails
        _loadFromLocal(prefs); 
      }
    } else {
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
      // Local bhi khali hai -> Force Fetch karo
      prefs.remove('last_metadata_fetch');
      // Infinite loop se bachne ke liye direct setState nahi, dubara try karo
      // Lekin agar yeh bhi fail hua to UI empty dikhayega.
      if (mounted) setState(() => _isDataLoading = false); 
    }
  }

  // 🔥 FAST GENERATE LOGIC
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
        throw "No questions found in selected topics.";
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
        content: const Text("Firebase needs an Index. Check debug console link."),
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
                 Expanded(child: Text("Expand subjects -> Add questions", style: TextStyle(fontSize: 12))),
               ],
             ),
           ),
           
           // ✅ LIST VIEW
           Expanded(
             child: _isDataLoading 
               ? const Center(child: CircularProgressIndicator()) 
               : _cachedSubjects.isEmpty 
                 ? Center(
                     child: Column(
                       mainAxisAlignment: MainAxisAlignment.center,
                       children: [
                         const Icon(Icons.error_outline, size: 40, color: Colors.grey),
                         const SizedBox(height: 10),
                         const Text("No subjects loaded."),
                         TextButton(onPressed: () {
                           // Retry Button
                           setState(() => _isDataLoading = true);
                           // Cache clear karke retry karo
                           SharedPreferences.getInstance().then((prefs) {
                             prefs.remove('last_metadata_fetch');
                             _loadDataWithCache();
                           });
                         }, child: const Text("Retry"))
                       ],
                     )
                   )
                 : ListView.builder(
                    itemCount: _cachedSubjects.length,
                    padding: const EdgeInsets.only(bottom: 100),
                    itemBuilder: (context, index) {
                      final sData = _cachedSubjects[index];
                      final sName = sData['subjectName'];
                      final sId = sData['id'];
                      
                      final rTopics = _cachedTopics.where((t) => t['subjectId'] == sId).toList();

                      if (rTopics.isEmpty) return const SizedBox.shrink();

                      return ExpansionTile(
                        title: Text(sName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        leading: const Icon(Icons.library_books, color: Colors.deepPurple),
                        children: rTopics.map((tData) {
                          final tName = tData['topicName'];
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
                                  Text("$count", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
