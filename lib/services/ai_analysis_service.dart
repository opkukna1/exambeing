import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';

class AiAnalysisService {
  // अपनी API Key यहाँ डालें (बेहतर होगा अगर आप इसे ENV फाइल में रखें)
  final String _apiKey = 'AIzaSyA2RwvlhdMHLe3r9Ivi592kxYR-IkIbnpQ'; 
  
  // 1. LIMIT CHECK & UPDATE FUNCTION
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
    final currentMonth = DateFormat('yyyy-MM').format(now);

    if (!doc.exists) {
      // First time user
      await docRef.set({'count': 1, 'month': currentMonth});
      return true;
    }

    final data = doc.data()!;
    String lastMonth = data['month'] ?? '';
    int count = data['count'] ?? 0;

    if (lastMonth != currentMonth) {
      // New Month: Reset count
      await docRef.set({'count': 1, 'month': currentMonth});
      return true;
    } else {
      // Same Month: Check limit
      if (count >= 5) {
        return false; // Limit Reached
      } else {
        await docRef.update({'count': FieldValue.increment(1)});
        return true;
      }
    }
  }

  // 2. FETCH USER PERFORMANCE DATA
  Future<String> _fetchUserStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return "";

    // यहाँ हम पिछले 10 टेस्ट के रिजल्ट्स निकालेंगे
    // मान रहा हूँ आपका collection 'test_results' है
    final query = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('test_results')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .get();

    if (query.docs.isEmpty) return "No test data available.";

    String statsData = "Here is the student's recent performance:\n";

    for (var doc in query.docs) {
      final data = doc.data();
      statsData += "- Test Topic: ${data['topicName']}\n";
      statsData += "  Score: ${data['score']}/${data['totalQuestions']}\n";
      // अगर आपके पास Question Type का डेटा है तो वो भी जोड़ें
      // जैसे: "  Mistakes in: Conceptual, Dates"
    }
    
    return statsData;
  }

  // 3. MAIN FUNCTION TO CALL GEMINI
  Future<String> getAnalysis() async {
    // A. Quota Check
    bool canUse = await _checkAndIncrementQuota();
    if (!canUse) {
      return "LIMIT_REACHED"; 
    }

    // B. Data Fetching
    String userData = await _fetchUserStats();
    if (userData.contains("No test data")) return "NO_DATA";

    // C. Gemini Call
    final model = GenerativeModel(model: 'gemini-pro', apiKey: _apiKey);

    final prompt = """
    You are an expert Exam Mentor for competitive exams. Analyze the student's performance data below perfectly.
    
    $userData

    Based on this, provide a response in HINDI (mix with English terms) covering:
    1. **Strong Areas:** What are they good at?
    2. **Weak Areas:** Which subjects/topics need work?
    3. **Pattern Analysis:** Are they failing in Factual (Dates/Names) or Analytical (Logic) questions? (Infer this).
    4. **Actionable Strategy:** Give a 3-step plan for next week.
    
    Keep the tone encouraging but strict like a coach. Use Bullet points.
    """;

    try {
      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      return response.text ?? "Error generating analysis.";
    } catch (e) {
      return "Error: $e";
    }
  }
}
