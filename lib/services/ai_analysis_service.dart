import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';

class AiAnalysisService {
  // ✅ API Key ab Environment se aayegi (GitHub Secret se inject hogi)
  // Local run ke liye command line argument dena padega
  final String _apiKey = const String.fromEnvironment('GEMINI_API_KEY');
  
  // 1. LIMIT CHECK & UPDATE FUNCTION (5 Times/Month)
  Future<bool> _checkAndIncrementQuota() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('ai_usage')
        .doc('stats');

    final doc = await docRef.get();
    final now = DateTime.now();
    final currentMonth = DateFormat('yyyy-MM').format(now); // e.g., "2025-10"

    if (!doc.exists) {
      // First time use: Create doc
      await docRef.set({'count': 1, 'month': currentMonth});
      return true;
    }

    final data = doc.data()!;
    String lastMonth = data['month'] ?? '';
    int count = data['count'] ?? 0;

    if (lastMonth != currentMonth) {
      // New Month: Reset count to 1
      await docRef.set({'count': 1, 'month': currentMonth});
      return true;
    } else {
      // Same Month: Check limit
      if (count >= 5) {
        return false; // Limit Reached
      } else {
        // Increment count
        await docRef.update({'count': FieldValue.increment(1)});
        return true;
      }
    }
  }

  // 2. FETCH USER PERFORMANCE DATA (Last 10 Tests)
  Future<String> _fetchUserStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return "";

    // Assuming results are stored in 'users/{uid}/test_results'
    final query = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('test_results')
        .orderBy('timestamp', descending: true)
        .limit(10)
        .get();

    if (query.docs.isEmpty) return "No test data available.";

    String statsData = "Student's Recent Performance History:\n";

    for (var doc in query.docs) {
      final data = doc.data();
      // Data safe check
      String topic = data['topicName'] ?? 'Unknown Topic';
      var score = data['score'] ?? 0;
      var total = data['totalQuestions'] ?? 0;
      
      statsData += "- Topic: $topic | Score: $score/$total\n";
    }
    
    return statsData;
  }

  // 3. MAIN FUNCTION TO CALL GEMINI
  Future<String> getAnalysis() async {
    
    // Safety Check: Agar Key load nahi hui
    if (_apiKey.isEmpty) {
      return "Error: API Key missing. Please run app with --dart-define.";
    }

    // A. Check Quota
    bool canUse = await _checkAndIncrementQuota();
    if (!canUse) {
      return "LIMIT_REACHED"; 
    }

    // B. Fetch Data
    String userData = await _fetchUserStats();
    if (userData.contains("No test data")) return "NO_DATA";

    // C. Initialize Gemini
    final model = GenerativeModel(model: 'gemini-pro', apiKey: _apiKey);

    // D. The Prompt (Hindi Response ke liye)
    final prompt = """
    You are an expert Exam Mentor (Coach) for competitive exams like UPSC/SSC. 
    Analyze this student's performance data:
    
    $userData

    Based on this data, provide a structured analysis in **HINDI (Mixed with English terms)**.
    The response must follow this format strictly using Markdown:

    ### 🟢 Strong Areas (मजबूत पक्ष)
    [List 2-3 topics where score is high]

    ### 🔴 Weak Areas (कमजोर पक्ष)
    [List 2-3 topics where score is low]

    ### 🔍 Pattern Analysis
    [Analyze if they are making silly mistakes or lacking conceptual clarity]

    ### 🚀 Action Plan for Next Week
    1. [Step 1]
    2. [Step 2]
    3. [Step 3]
    
    Keep the tone motivating but professional.
    """;

    try {
      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      return response.text ?? "Unable to generate analysis at this moment.";
    } catch (e) {
      return "Error connecting to AI: $e";
    }
  }
}
