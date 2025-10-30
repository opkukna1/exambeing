import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../models/question_model.dart';
import '../../../services/firebase_data_service.dart';

// ⬇️===== NAYE IMPORTS (AdMob Ke Liye) =====⬇️
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io' show Platform; // Platform check karne ke liye
// ⬆️=======================================⬆️

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

  // ⬇️===== NAYE VARIABLES (AdMob Ke Liye) =====⬇️
  InterstitialAd? _interstitialAd;
  bool _isAdLoaded = false;
  // User ne kaun sa set chuna hai, use ad band hone tak save rakhein
  List<Question>? _selectedQuestionSet; 

  // Google ki Test Ad Unit ID (Asli ID se badalna hoga)
  final String _adUnitId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/1033173712'
      : 'ca-app-pub-3940256099942544/4411468910'; // iOS (agar use karein)
  // ⬆️=========================================⬆️

  @override
  void initState() {
    super.initState();
    topicId = widget.topicData['topicId']!;
    topicName = widget.topicData['topicName']!;
    _questionsFuture = dataService.getQuestions(topicId);
    
    // ⬇️===== NAYA FUNCTION CALL (Ad Load Karne Ke Liye) =====⬇️
    _loadInterstitialAd();
    // ⬆️===================================================⬆️
  }

  // ⬇️===== NAYA FUNCTION (Ad Ko Dispose Karne Ke Liye) =====⬇️
  @override
  void dispose() {
    _interstitialAd?.dispose(); // Ad ko memory se hatayein
    super.dispose();
  }
  // ⬆️===================================================⬆️

  // ⬇️===== NAYA FUNCTION (Ad Load Karne Ke Liye) =====⬇️
  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        // Ad safalta se load hone par
        onAdLoaded: (InterstitialAd ad) {
          debugPrint('Ad loaded.');
          _interstitialAd = ad;
          _isAdLoaded = true;

          // Ad ke events set karein (jaise user ne ad band kiya)
          _setAdCallbacks();
        },
        // Ad load fail hone par
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('InterstitialAd failed to load: $error');
          _isAdLoaded = false;
        },
      ),
    );
  }
  // ⬆️===================================================⬆️

  // ⬇️===== NAYA FUNCTION (Ad Events Ko Set Karne Ke Liye) =====⬇️
  void _setAdCallbacks() {
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      // Ad dikhne mein fail hone par
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        debugPrint('Ad failed to show: $error');
        ad.dispose();
        _isAdLoaded = false;
        // Ad fail ho gaya, to user ko seedha dialog dikha do
        if (_selectedQuestionSet != null) {
          _showModeSelectionDialog(_selectedQuestionSet!);
          _selectedQuestionSet = null; // Clean up
        }
        _loadInterstitialAd(); // Agla ad load karo
      },
      // User dwara Ad band karne par
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        debugPrint('Ad dismissed.');
        ad.dispose();
        _isAdLoaded = false;
        // Ad band ho gaya, ab user ko dialog dikha do
        if (_selectedQuestionSet != null) {
          _showModeSelectionDialog(_selectedQuestionSet!);
          _selectedQuestionSet = null; // Clean up
        }
        _loadInterstitialAd(); // Agla ad load karo
      },
    );
  }
  // ⬆️=======================================================⬆️

  // ⬇️===== NAYA FUNCTION (Ad Dikhane Ke Liye) =====⬇️
  void _showInterstitialAd(List<Question> questionSet) {
    // Pehle question set ko save karo, taaki ad band hone ke baad use kar sakein
    _selectedQuestionSet = questionSet;

    // Check karo ki ad load ho chuka hai ya nahi
    if (_interstitialAd != null && _isAdLoaded) {
      _interstitialAd!.show(); // Ad dikhao
      _isAdLoaded = false; // Ad ek hi baar dikhta hai
    } else {
      // Agar ad ready nahi hai (internet nahi hai ya load ho raha hai)
      debugPrint('Ad not ready. Showing dialog directly.');
      _showModeSelectionDialog(questionSet); // Seedha dialog dikha do
      _selectedQuestionSet = null; // Clean up
      _loadInterstitialAd(); // Agle click ke liye ad load karne ki koshish karo
    }
  }
  // ⬆️=================================================⬆️

  void _showModeSelectionDialog(List<Question> questionSet) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Choose Your Mode'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
        // ⬇️===== 'onTap' KO UPDATE KIYA GAYA HAI =====⬇️
        onTap: () {
          // Ab ad dikhane waala function call hoga
          _showInterstitialAd(questionSet);
        },
        // ⬆️=========================================⬆️
      ),
    );
  }
}
