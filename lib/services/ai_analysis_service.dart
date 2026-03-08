import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart'; // <--- AI Package
import 'package:flutter_dotenv/flutter_dotenv.dart'; // <--- Secret Key Package

class AiAnalysisService {
  
  // 1. Quota Logic (Unlimited for local)
  Future<bool> _checkAndIncrementQuota() async {
    return true; 
  }

  // 2. FETCH DATA & ANALYZE LOCALLY
  Future<String> getAnalysis() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return "Error: User not logged in.";

      // Name Format (Ram Kumar -> Ram)
      String userName = user.displayName?.split(' ')[0] ?? "Aspirant";

      // A. Fetch Last 25 Tests
      final query = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('test_results')
          .orderBy('timestamp', descending: true)
          .limit(25) 
          .get();

      if (query.docs.isEmpty) return "NO_DATA";

      // B. VARIABLES FOR LOGIC
      Map<String, int> topicCorrect = {};
      Map<String, int> topicTotal = {};
      int totalCorrect = 0;
      int totalQuestions = 0;

      // C. Process Data (Deep Calculation)
      for (var doc in query.docs) {
        final data = doc.data();
        String topic = data['topicName'] ?? "General";
        
        List<dynamic> logs = data['logs'] ?? [];

        if (logs.isNotEmpty) {
          for (var log in logs) {
            bool isCorrect = log['s'] ?? false;
            
            topicTotal[topic] = (topicTotal[topic] ?? 0) + 1;
            if (isCorrect) {
              topicCorrect[topic] = (topicCorrect[topic] ?? 0) + 1;
              totalCorrect++;
            }
            totalQuestions++;
          }
        } else {
          int score = data['score'] ?? 0;
          int total = data['totalQuestions'] ?? 0;
          
          topicTotal[topic] = (topicTotal[topic] ?? 0) + total;
          topicCorrect[topic] = (topicCorrect[topic] ?? 0) + score;
          totalCorrect += score;
          totalQuestions += total;
        }
      }

      if (totalQuestions == 0) return "NO_DATA";

      // D. Find Weak & Strong Topics
      String strongTopic = "None";
      String weakTopic = "None";
      double highestPercent = -1;
      double lowestPercent = 101;

      topicTotal.forEach((topic, total) {
        if (total >= 5) { // Kam se kam 5 sawal attempt kiye ho
          int correct = topicCorrect[topic] ?? 0;
          double percent = (correct / total) * 100;

          if (percent > highestPercent) {
            highestPercent = percent;
            strongTopic = topic;
          }
          if (percent < lowestPercent) {
            lowestPercent = percent;
            weakTopic = topic;
          }
        }
      });

      double overallPercentage = (totalCorrect / totalQuestions) * 100;

      // E. GENERATE SMART RESPONSE VIA GEMINI AI
      return await _generateAiMessage(
        name: userName,
        percentage: overallPercentage,
        strong: strongTopic,
        weak: weakTopic,
        totalQ: totalQuestions,
      );

    } catch (e) {
      return "Error generating analysis: $e";
    }
  }

  // 3. THE BRAIN 🧠 (Powered by Gemini 3.1 Flash Lite)
  Future<String> _generateAiMessage({
    required String name,
    required double percentage,
    required String strong,
    required String weak,
    required int totalQ,
  }) async {
    try {
      // API Key .env se uthana
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        return "Error: AI Tutor is currently sleeping. (API Key missing)";
      }

      // Gemini Model Initialize karna
      final model = GenerativeModel(
        model: 'gemini-3.1-flash-lite',
        apiKey: apiKey,
      );

      // AI ko Exambeing ke tutor ki tarah train karne ke liye faadu Prompt
      final prompt = """
      You are an expert, encouraging, and highly observant AI Tutor for an exam preparation app named 'Exambeing'.
      Write a short, personalized performance analysis for a student based on the following exact data:
      
      - Student Name: $name
      - Overall Accuracy: ${percentage.toStringAsFixed(1)}%
      - Total Questions Attempted: $totalQ
      - Strongest Topic: $strong
      - Weakest Topic: $weak

      Rules for the response:
      1. Write directly to the student in a conversational, motivating tone (mix of English and a little bit of casual Hindi if it sounds natural, like a friendly mentor).
      2. Use Markdown formatting (headings, bullet points, bold text).
      3. Start with a catchy headline.
      4. Congratulate them on their strong topic.
      5. Provide a specific, actionable tip to improve their weak topic. 
      6. Keep it concise (under 150 words). Do not use generic filler text.
      """;

      // AI se response mangna
      final response = await model.generateContent([Content.text(prompt)]);
      
      return response.text ?? "We couldn't analyze your performance right now. Please try taking another test!";
      
    } catch (e) {
      debugPrint("Gemini AI Error: $e");
      // Agar AI fail ho jaye (internet issue etc), toh ek default fallback message dikhayenge
      return """
### 📊 Basic Analysis for $name
- **Score:** ${percentage.toStringAsFixed(1)}%
- **Strong Topic:** $strong
- **Needs Work:** $weak

*Note: Connect to the internet for a detailed AI Tutor analysis!*
""";
    }
  }
}
