import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/topic_model.dart';
import '../../../models/question_model.dart';
import '../../../services/firebase_data_service.dart';

// ✅ AdManager Import
import 'package:exambeing/services/ad_manager.dart';

class TopicsScreen extends StatefulWidget {
  final Map<String, String> subjectData;
  const TopicsScreen({super.key, required this.subjectData});

  @override
  State<TopicsScreen> createState() => _TopicsScreenState();
}

class _TopicsScreenState extends State<TopicsScreen> {
  final FirebaseDataService dataService = FirebaseDataService();
  
  // Local list to handle reordering instantly
  List<Topic> _topics = [];
  bool _isLoading = true;
  bool _isReordering = false; // To toggle edit mode
  bool _isAdmin = false;      // To check admin status

  late String subjectId;
  late String subjectName;
  bool _isLoadingTest = false;

  @override
  void initState() {
    super.initState();
    subjectId = widget.subjectData['subjectId']!;
    subjectName = widget.subjectData['subjectName']!;
    
    _checkAdmin();
    _fetchAndSortTopics();
    
    // ✅ Ad Pre-load
    AdManager.loadInterstitialAd();
  }

  // 🔒 1. Check if user is Admin
  void _checkAdmin() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email == "opsiddh42@gmail.com") {
      setState(() {
        _isAdmin = true;
      });
    }
  }

  // 📥 2. Fetch Topics sorted by 'rank'
  Future<void> _fetchAndSortTopics() async {
    try {
      // Direct Firestore call to ensure we get 'rank' field handling right
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('subjects')
          .doc(subjectId)
          .collection('topics')
          .orderBy('rank', descending: false) // Sort by rank (1, 2, 3...)
          .get();

      List<Topic> loadedTopics = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        // Agar rank nahi hai to default 9999 manenge taaki wo end me dikhe
        return Topic(
          id: doc.id,
          name: data['name'] ?? 'Unknown Topic',
          imageUrl: data['imageUrl'] ?? '',
          // Rank model me nahi hai to ignore karein, hum UI me list index use karenge
        );
      }).toList();

      if (mounted) {
        setState(() {
          _topics = loadedTopics;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching topics: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 💾 3. Save New Order to Firestore
  Future<void> _saveNewOrder() async {
    setState(() => _isLoading = true);
    
    WriteBatch batch = FirebaseFirestore.instance.batch();

    for (int i = 0; i < _topics.length; i++) {
      DocumentReference ref = FirebaseFirestore.instance
          .collection('subjects')
          .doc(subjectId)
          .collection('topics')
          .doc(_topics[i].id);
      
      // Update 'rank' field (1 se shuru hoga)
      batch.update(ref, {'rank': i + 1});
    }

    try {
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Topic Order Saved Successfully!")),
        );
        setState(() {
          _isReordering = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving order: $e")),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  // --- Quiz Navigation Logic ---
  void _navigateToQuiz(Topic topic, String mode) {
    if (mode == 'practice') {
      final topicData = {'topicId': topic.id, 'topicName': topic.name};
      context.push('/sets', extra: topicData);
    } else { 
      _startTestMode(topic);
    }
  }

  void _startTestMode(Topic topic) async {
    setState(() {
      _isLoadingTest = true;
    });

    try {
      final List<Question> questions = await dataService.getQuestions(topic.id);

      if (mounted) setState(() => _isLoadingTest = false);
      
      if (questions.isEmpty) {
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No questions found for this topic.')),
          );
        }
        return;
      }

      if (mounted) {
        context.push(
          '/practice-mcq',
          extra: {
            'questions': questions,
            'topicName': topic.name,
            'mode': 'test',
          },
        );
      }
    } catch (e) {
       if (mounted) {
        setState(() => _isLoadingTest = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load test: $e')));
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
                subtitle: const Text('Practice in sets with solutions'),
                onTap: () {
                  Navigator.pop(dialogContext);
                  _navigateToQuiz(topic, 'practice');
                },
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.timer, color: Theme.of(context).colorScheme.secondary),
                title: const Text('Test Mode'),
                subtitle: const Text('Full test for this topic'),
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
        title: Text(_isReordering ? "Drag to Reorder" : subjectName),
        elevation: 0,
        actions: [
          // 🔒 ADMIN ONLY: Reorder Button
          if (_isAdmin)
            IconButton(
              icon: Icon(_isReordering ? Icons.save_rounded : Icons.sort_rounded),
              tooltip: _isReordering ? "Save Order" : "Edit Order",
              color: _isReordering ? Colors.green : Colors.black,
              onPressed: () {
                if (_isReordering) {
                  _saveNewOrder(); // Save changes
                } else {
                  setState(() => _isReordering = true); // Enable drag mode
                }
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_topics.isEmpty)
            const Center(child: Text('No topics found.'))
          else
            _isReordering
                ? _buildReorderableList() // 🔀 Admin Drag & Drop View
                : _buildNormalList(),     // 📄 Normal User View

          if (_isLoadingTest)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text("Loading Test...", style: TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 📄 Normal User List
  Widget _buildNormalList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      itemCount: _topics.length,
      itemBuilder: (context, index) {
        return _buildTopicCard(context, _topics[index], index, false);
      },
    );
  }

  // 🔀 Admin Reorderable List
  Widget _buildReorderableList() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      itemCount: _topics.length,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (oldIndex < newIndex) newIndex -= 1;
          final Topic item = _topics.removeAt(oldIndex);
          _topics.insert(newIndex, item);
        });
      },
      itemBuilder: (context, index) {
        // Key is required for ReorderableListView
        return _buildTopicCard(context, _topics[index], index, true);
      },
    );
  }

  // 🔥 UPDATED MODERN CARD
  Widget _buildTopicCard(BuildContext context, Topic topic, int index, bool isEditing) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      key: Key(topic.id), // Important for Reordering
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isEditing ? Border.all(color: Colors.green, width: 2) : null, // Highlight in edit mode
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
          // Edit mode me tap disable, drag enable
          onTap: isEditing ? null : () => _showModeSelectionDialog(topic),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // 🎨 Edit Mode: Drag Handle | Normal Mode: Index
                if (isEditing)
                  const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: Icon(Icons.drag_handle_rounded, color: Colors.grey),
                  )
                else
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
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
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
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (!isEditing) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.category_outlined, size: 12, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text(
                              subjectName,
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ]
                    ],
                  ),
                ),
                
                // ▶️ Start Button (Hidden in Edit Mode)
                if (!isEditing)
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
          ),
        ),
      ),
    );
  }
}
