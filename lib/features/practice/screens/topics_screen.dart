import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../models/topic_model.dart';
import '../../../models/question_model.dart';
import '../../../services/firebase_data_service.dart';

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

  // RewardedAd related variables and methods have been removed.

  @override
  void initState() {
    super.initState();
    subjectId = widget.subjectData['subjectId']!;
    subjectName = widget.subjectData['subjectName']!;
    _topicsFuture = dataService.getTopics(subjectId);
    // _loadRewardedAd() call removed.
  }

  // _loadRewardedAd() and _showRewardedAdAndStartTest() methods removed.

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
              ListTile(
                leading: Icon(Icons.edit_note, color: Theme.of(context).colorScheme.primary),
                title: const Text('Practice Mode'),
                subtitle: const Text('Practice in sets with solutions'),
                onTap: () {
                  Navigator.pop(dialogContext);
                  // Directly navigate, bypassing the ad.
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
                  // Directly navigate, bypassing the ad.
                  _navigateToQuiz(topic, 'test');
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
      appBar: AppBar(
        title: Text(subjectName),
      ),
      bottomNavigationBar: _buildBuyNowBar(context),
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
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
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

  Widget _buildTopicCard(BuildContext context, Topic topic, int index) {
    return Card(
      color: Theme.of(context).colorScheme.primary,
      margin: const EdgeInsets.only(bottom: 16.0),
      child: InkWell(
        onTap: () => _showModeSelectionDialog(topic),
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Column(
                children: [
                  Icon(Icons.list_alt_rounded, color: Colors.white.withOpacity(0.7), size: 30),
                  const SizedBox(height: 4),
                  Text('Test', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${index + 1} ${topic.name}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Subject: $subjectName',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withOpacity(0.8),
                          ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _showModeSelectionDialog(topic),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.15),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Start Test'),
                          SizedBox(width: 8),
                          Icon(Icons.lock_outline, size: 16),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBuyNowBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () { /* Handle purchase logic */ },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.teal.shade400,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: const Text('₹199 Buy Now'),
      ),
    );
  }
}
