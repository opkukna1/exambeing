import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart'; 
import 'package:flutter_dotenv/flutter_dotenv.dart'; 

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

  // 3. THE BRAIN 🧠 (Powered by Gemini)
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

      // 🔥 MODEL NAME CORRECTED 🔥
      final model = GenerativeModel(
        model: 'gemini-3.1-flash-lite-preview', // Sahi aur fast model
        apiKey: apiKey,
      );

      // 🔥 NEW ELITE EXAM STRATEGIST PROMPT 🔥
      final prompt = """
      You are an elite exam strategist and mentor for a competitive exam preparation platform called "Exambeing".

      Your job is to analyze the student's performance data and provide a sharp, practical coaching insight — not generic motivation.

      Student Performance Data:
      - Name: $name
      - Overall Accuracy: ${percentage.toStringAsFixed(1)}%
      - Total Questions Attempted: $totalQ
      - Strongest Topic: $strong
      - Weakest Topic: $weak

      Instructions:

      1. Start with a short motivational headline.
      2. Briefly interpret what this accuracy level means for competitive exams like UPSC/RPSC.
      3. Identify the student's likely preparation pattern from the data.
      4. Praise the strongest topic and explain how the student can convert this strength into guaranteed exam marks.
      5. Diagnose possible reasons for weakness in the weakest topic (concept gap, revision issue, memory-based subject etc).
      6. Provide a **3-step practical improvement strategy** specifically for the weak topic.
      7. Give one **smart exam strategy tip** (like elimination technique, revision pattern, mock test usage).
      8. End with a short motivating line like a mentor encouraging a serious aspirant.

      Rules:
      - Use Markdown formatting (headings, bullet points).
      - Keep response under 180 words.
      - Write in natural Hinglish like a friendly mentor.
      - Avoid generic advice like "study more" or "work hard".
      - Sound like a real exam coach analyzing performance.
      """;

      // AI se response mangna
      final response = await model.generateContent([Content.text(prompt)]);
      
      return response.text ?? "We couldn't analyze your performance right now. Please try taking another test!";
      
    } catch (e) {
      debugPrint("Gemini AI Error: $e");
      // Agar AI fail ho jaye (internet issue etc), toh ek default fallback message dikhayenge
      return """
🚨 AI Error Details: $e

---

### 📊 Basic Analysis for $name
- **Score:** ${percentage.toStringAsFixed(1)}%
- **Strong Topic:** $strong
- **Needs Work:** $weak

*Note: Connect to the internet for a detailed AI Tutor analysis!*
""";
    }
  }
}
