import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/topic_model.dart';
import '../../../models/question_model.dart';
import '../../../services/firebase_data_service.dart';
import 'package:exambeing/services/ad_manager.dart';

class TopicsScreen extends StatefulWidget {
  final Map<String, String> subjectData;
  const TopicsScreen({super.key, required this.subjectData});

  @override
  State<TopicsScreen> createState() => _TopicsScreenState();
}

class _TopicsScreenState extends State<TopicsScreen> {
  final FirebaseDataService dataService = FirebaseDataService();
  
  List<Topic> _topics = [];
  bool _isLoading = true;
  bool _isAdmin = false; 

  late String subjectId;
  late String subjectName;
  bool _isLoadingTest = false;

  @override
  void initState() {
    super.initState();
    // Safety check
    if (widget.subjectData['subjectId'] == null) {
      setState(() => _isLoading = false);
      return;
    }

    subjectId = widget.subjectData['subjectId']!;
    subjectName = widget.subjectData['subjectName'] ?? 'Topics';
    
    _checkAdmin();
    _fetchAndSortTopics();
    
    // Ads load
    AdManager.loadInterstitialAd();
  }

  void _checkAdmin() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email?.toLowerCase() == "opsiddh42@gmail.com") {
      setState(() {
        _isAdmin = true;
      });
    }
  }

  // ✅ FIXED FETCHING LOGIC: Gets ALL topics regardless of Rank
  Future<void> _fetchAndSortTopics() async {
    try {
      // 1. Simple GET query (No 'orderBy' here to avoid hiding docs)
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('subjects')
          .doc(subjectId)
          .collection('topics')
          .get();

      List<QueryDocumentSnapshot> docs = snapshot.docs;

      // 2. Convert to Models
      List<Topic> loadedTopics = docs.map((doc) {
        // Model apne aap missing rank ko 9999 bana dega
        return Topic.fromFirestore(doc); 
      }).toList();

      // 3. Sort locally in the App
      loadedTopics.sort((a, b) {
        int rankA = a.rank; 
        int rankB = b.rank;
        return rankA.compareTo(rankB);
      });

      if (mounted) {
        setState(() {
          _topics = loadedTopics;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching topics: $e");
      if (mounted) {
         // Show error on screen if any
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
         setState(() => _isLoading = false);
      }
    }
  }

  // ✏️ Dialog to Edit Rank
  void _showEditRankDialog(Topic topic) {
    TextEditingController rankController = TextEditingController();
    
    // Sirf tab dikhao jab rank set ho (9999 mtlb unset)
    if (topic.rank != 9999) {
      rankController.text = topic.rank.toString();
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Set Rank for ${topic.name}"),
          content: TextField(
            controller: rankController,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: "Enter Rank Number",
              border: OutlineInputBorder(),
              helperText: "1 = Top, 2 = Second, etc.",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                String val = rankController.text.trim();
                if (val.isNotEmpty) {
                  int? newRank = int.tryParse(val);
                  if (newRank != null) {
                    Navigator.pop(context); // Close dialog
                    await _updateTopicRank(topic.id, newRank); // Save
                  }
                }
              },
              child: const Text("Save"),
            )
          ],
        );
      },
    );
  }

  // 💾 Update Rank in Firebase
  Future<void> _updateTopicRank(String topicId, int newRank) async {
    // Show loading indicator briefly
    ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(content: Text("Updating rank..."), duration: Duration(milliseconds: 500)),
    );

    try {
      await FirebaseFirestore.instance
          .collection('subjects')
          .doc(subjectId)
          .collection('topics')
          .doc(topicId)
          .update({'rank': newRank});

      // Refresh list to show new order immediately
      await _fetchAndSortTopics();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  void _navigateToQuiz(Topic topic, String mode) {
    if (mode == 'practice') {
      final topicData = {'topicId': topic.id, 'topicName': topic.name};
      context.push('/sets', extra: topicData);
    } else { 
      _startTestMode(topic);
    }
  }

  void _startTestMode(Topic topic) async {
    setState(() => _isLoadingTest = true);
    try {
      final List<Question> questions = await dataService.getQuestions(topic.id);
      if (mounted) setState(() => _isLoadingTest = false);
      
      if (questions.isEmpty) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No questions found.')));
        return;
      }
      if (mounted) {
        context.push('/practice-mcq', extra: {'questions': questions, 'topicName': topic.name, 'mode': 'test'});
      }
    } catch (e) {
       if (mounted) {
        setState(() => _isLoadingTest = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  void _showModeSelectionDialog(Topic topic) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(topic.name),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.edit_note, color: Theme.of(context).colorScheme.primary),
                title: const Text('Practice Mode'),
                subtitle: const Text('Practice in sets'),
                onTap: () {
                  Navigator.pop(dialogContext);
                  _navigateToQuiz(topic, 'practice');
                },
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.timer, color: Theme.of(context).colorScheme.secondary),
                title: const Text('Test Mode'),
                subtitle: const Text('Full test'),
                onTap: () {
                  Navigator.pop(dialogContext);
                  AdManager.showInterstitialAd(() {
                    _navigateToQuiz(topic, 'test');
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(subjectName),
        elevation: 0,
      ),
      body: Stack(
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_topics.isEmpty)
             Center(child: Column(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                 const SizedBox(height: 10),
                 const Text('No topics found.'),
               ],
             ))
          else
            ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
              itemCount: _topics.length,
              itemBuilder: (context, index) {
                return _buildTopicCard(context, _topics[index], index);
              },
            ),

          if (_isLoadingTest)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopicCard(BuildContext context, Topic topic, int index) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showModeSelectionDialog(topic),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // 🔢 Index Number (Card ka number, not Rank)
                Container(
                  height: 50,
                  width: 50,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor),
                    ),
                  ),
                ),
                
                // 📝 Topic Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topic.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      // Agar Rank set hai to dikhao (Admin Only)
                      if (_isAdmin)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            topic.rank == 9999 ? "No Rank Set" : "Rank Order: ${topic.rank}",
                            style: TextStyle(
                              fontSize: 10, 
                              color: topic.rank == 9999 ? Colors.red : Colors.green, 
                              fontWeight: FontWeight.bold
                            ),
                          ),
                        )
                      else 
                        const SizedBox(height: 4),
                        
                      Row(
                        children: [
                          Icon(Icons.category_outlined, size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(subjectName, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                    ],
                  ),
                ),

                // ⚙️ ACTION BUTTONS
                Row(
                  children: [
                    // ✏️ ADMIN PENCIL BUTTON (Sirf Admin ko dikhega)
                    if (_isAdmin)
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.orange),
                        onPressed: () => _showEditRankDialog(topic),
                        tooltip: "Set Rank",
                      ),

                    // ▶️ START BUTTON
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Text(
                        "Start",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
