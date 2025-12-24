import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  late Future<List<Topic>> _topicsFuture;
  late String subjectId;
  late String subjectName;
  bool _isLoadingTest = false;

  @override
  void initState() {
    super.initState();
    subjectId = widget.subjectData['subjectId']!;
    subjectName = widget.subjectData['subjectName']!;
    _topicsFuture = dataService.getTopics(subjectId);
    
    // ✅ Ad Pre-load
    AdManager.loadInterstitialAd();
  }

  void _navigateToQuiz(Topic topic, String mode) {
    if (mode == 'practice') {
      final topicData = {'topicId': topic.id, 'topicName': topic.name};
      context.push('/sets', extra: topicData);
    } else { // Test Mode
      _startTestMode(topic);
    }
  }

  void _startTestMode(Topic topic) async {
    setState(() {
      _isLoadingTest = true;
    });

    try {
      final List<Question> questions = await dataService.getQuestions(topic.id);

      if (mounted) {
        setState(() {
          _isLoadingTest = false;
        });
      }
      
      if (questions.isEmpty) {
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No questions found for this topic to start a test.')),
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
        setState(() {
          _isLoadingTest = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load test: $e')),
        );
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
              // --- PRACTICE MODE (No Ad) ---
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
              
              // --- TEST MODE (With Ad) ---
              ListTile(
                leading: Icon(Icons.timer, color: Theme.of(context).colorScheme.secondary),
                title: const Text('Test Mode'),
                subtitle: const Text('Full test for this topic'),
                onTap: () {
                  Navigator.pop(dialogContext);
                  
                  // ✅ Test Mode: Pehle Ad dikhao
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
      backgroundColor: Colors.grey.shade50, // Slight grey background taaki cards pop karein
      appBar: AppBar(
        title: Text(subjectName),
        elevation: 0,
      ),
      body: Stack(
        children: [
          FutureBuilder<List<Topic>>(
            future: _topicsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No topics found for this subject.'));
              }

              final topics = snapshot.data!;
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                itemCount: topics.length,
                itemBuilder: (context, index) {
                  final topic = topics[index];
                  return _buildTopicCard(context, topic, index);
                },
              );
            },
          ),
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

  // 🔥 UPDATED MODERN CARD (No Lock, Clean Look)
  Widget _buildTopicCard(BuildContext context, Topic topic, int index) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: Colors.white, // Clean white background
        borderRadius: BorderRadius.circular(20), // Modern rounded corners
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4), // Soft shadow
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
                // 🎨 Modern Index Number Box
                Container(
                  height: 50,
                  width: 50,
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
                const SizedBox(width: 16),
                
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
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.category_outlined, size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            subjectName,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // ▶️ Start Button (No Lock Icon anymore)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(30), // Capsule shape
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
