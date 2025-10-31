import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../models/question_model.dart';
import '../../../services/firebase_data_service.dart';

// ⬇️===== NAYE IMPORTS =====⬇️
import 'package:provider/provider.dart';
import '../../../services/ad_service_provider.dart'; // Hamari Ad Service file
// ⬆️=======================⬆️

// ❌ (google_mobile_ads aur dart:io import hata diye gaye)

class SetsScreen extends StatefulWidget {
  final Map<String, String> topicData;
  const SetsScreen({super.key, required this.topicData});

  @override
  State<SetsScreen> createState() => _SetsScreenState();
}

class _SetsScreenState extends State<SetsScreen> {
  final FirebaseDataService dataService = FirebaseDataService();
  late Future<List<Question>> _questionsFuture;

  late String topicId;
  late String topicName;
  final int setSize = 25;

  // ❌ (Ad-related variables hata diye gaye)
  // InterstitialAd? _interstitialAd;
  // bool _isAdLoaded = false;
  // List<Question>? _selectedQuestionSet; 
  // final String _adUnitId = ...;

  @override
  void initState() {
    super.initState();
    topicId = widget.topicData['topicId']!;
    topicName = widget.topicData['topicName']!;
    _questionsFuture = dataService.getQuestions(topicId);
    
    // ❌ (_loadInterstitialAd() call hata diya gaya)
  }

  // ❌ (dispose() method hata diya gaya, kyonki ad yahaan manage nahi ho raha)

  // ❌ (Saare puraane ad functions hata diye gaye: 
  // _loadInterstitialAd, _setAdCallbacks, _showInterstitialAd)
  
  void _showModeSelectionDialog(List<Question> questionSet) {
    // Yeh function waisa hi hai
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Choose Your Mode'),
          shape: RoundedRectangleR ectBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.edit_note, color: Theme.of(context).colorScheme.primary),
                title: const Text('Practice Mode', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Get instant feedback & explanations.'),
                onTap: () {
                  Navigator.pop(dialogContext);
                  context.push(
                    '/practice-mcq',
                    extra: {
                      'questions': questionSet,
                      'topicName': topicName,
                      'mode': 'practice',
                    },
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.timer_outlined, color: Theme.of(context).colorScheme.secondary),
                title: const Text('Test Mode', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Simulate a real exam with a timer.'),
                onTap: () {
                  Navigator.pop(dialogContext);
                  context.push(
                    '/practice-mcq',
                    extra: {
                      'questions': questionSet,
                      'topicName': topicName,
                      'mode': 'test',
                    },
                  );
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
        title: Text(topicName),
      ),
      body: FutureBuilder<List<Question>>(
        future: _questionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No questions found for this topic.'));
          }

          final allQuestions = snapshot.data!;
          final numberOfSets = (allQuestions.length / setSize).ceil();

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
            itemCount: numberOfSets,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final setIndex = index + 1;
              final questionSet = allQuestions.sublist(
                index * setSize,
                (index * setSize + setSize > allQuestions.length)
                    ? allQuestions.length
                    : index * setSize + setSize,
              );

              return _buildSetCard(context, setIndex, questionSet);
            },
          );
        },
      ),
    );
  }

  Widget _buildSetCard(BuildContext context, int setIndex, List<Question> questionSet) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            '$setIndex',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        title: Text(
          'Set $setIndex',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${questionSet.length} Questions'),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
        // ⬇️===== 'onTap' KO NAYE PROVIDER SE UPDATE KIYA GAYA HAI =====⬇️
        onTap: () {
          // 1. Provider ko access karo
          final adProvider = Provider.of<AdServiceProvider>(context, listen: false);

          // 2. Ad dikhane ke liye kaho.
          // Ad band hone ke baad 'onAdDismissed' function chalega.
          adProvider.showAdAndNavigate(
            () {
              // Yeh code ad band hone ke baad chalega
              if (mounted) { 
                _showModeSelectionDialog(questionSet);
              }
            },
          );
        },
        // ⬆️=========================================================⬆️
      ),
    );
  }
}
