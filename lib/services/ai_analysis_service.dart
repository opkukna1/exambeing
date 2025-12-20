import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart'; 

class AiAnalysisService {
  
  // ⚠️ API KEY (Apni Key Yahan Rakhein)
  static const String _apiKey = 'AIzaSyA2RwvlhdMHLe3r9Ivi592kxYR-IkIbnpQ'; 

  // 1. LIMIT CHECK (Same as before)
  Future<bool> _checkAndIncrementQuota() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('ai_usage').doc('stats');
      final doc = await docRef.get();
      final now = DateTime.now();
      final currentMonth = DateFormat('yyyy-MM').format(now);

      if (!doc.exists) {
        await docRef.set({'count': 1, 'month': currentMonth});
        return true;
      }

      final data = doc.data()!;
      if (data['month'] != currentMonth) {
        await docRef.set({'count': 1, 'month': currentMonth});
        return true;
      } else {
        if ((data['count'] ?? 0) >= 5) return false;
        await docRef.update({'count': FieldValue.increment(1)});
        return true;
      }
    } catch (e) {
      return true; // Fallback
    }
  }

  // 2. FETCH DETAILED LOGS (Updated to read 'logs' array)
  Future<String> _fetchUserStats() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return "";

      // Pichhle 20 Tests uthayenge (Agar har test mein 25 sawal hue to 500 questions ho jayenge)
      final query = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('test_results')
          .orderBy('timestamp', descending: true)
          .limit(20) 
          .get();

      if (query.docs.isEmpty) return "No test data available.";

      String statsData = "Here is the detailed log of recent questions attempted by the student:\n\n";
      int totalQuestionsRead = 0;

      for (var doc in query.docs) {
        final data = doc.data();
        String topic = data['topicName'] ?? "General";
        
        // 🔥 'logs' array ko dhoondho (Jo abhi naya save kar rahe hain)
        List<dynamic> logs = data['logs'] ?? [];

        if (logs.isEmpty) {
          // Agar logs nahi mile (Purana data), to sirf score dikha do
          var score = data['score'] ?? 0;
          statsData += "- Old Test ($topic): Score $score\n";
          continue;
        }

        // Agar Logs hain, to detail mein padho
        for (var log in logs) {
          String q = log['q'] ?? "";
          String u = log['u'] ?? ""; // User Answer
          String c = log['c'] ?? ""; // Correct Answer
          bool s = log['s'] ?? false; // Status (True/False)

          // AI ko bhejne ke liye format
          statsData += """
          [Topic: $topic]
          Q: $q
          User: $u | Correct: $c | Result: ${s ? "PASS" : "FAIL"}
          -------------------------
          """;
          
          totalQuestionsRead++;
        }
      }

      debugPrint("AI fetched $totalQuestionsRead questions for analysis.");
      return statsData;

    } catch (e) {
      debugPrint("Fetch Error: $e");
      return "Error fetching data.";
    }
  }

  // 3. MAIN FUNCTION
  Future<String> getAnalysis() async {
    if (_apiKey.isEmpty) return "Error: API Key is missing.";

    try {
      bool canUse = await _checkAndIncrementQuota();
      if (!canUse) return "LIMIT_REACHED";

      String userData = await _fetchUserStats();
      if (userData.contains("No test data")) return "NO_DATA";

      // Gemini Flash Model (Fast & Large Context)
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey);

      final prompt = """
      You are an elite Exam Coach. I am providing you with a log of the student's recent questions.
      
      DATA:
      $userData

      Analyze the QUESTIONS TEXT and ERRORS deeply.
      Response should be in **HINDI (Hinglish)** and STRICTLY follow this Markdown format:

      ### 📊 Performance Summary
      - **Consistency:** (Check if they are improving or failing randomly)
      - **Attempted:** (Total questions analyzed)

      ### 🔴 Weak Areas (कमजोर पक्ष)
      - [Identify specific topics/question types where result is FAIL]
      - e.g., "History dates are often wrong" or "Statement questions are weak".

      ### 🟢 Strong Areas (मजबूत पक्ष)
      - [Identify topics where result is PASS]

      ### 💡 Smart Strategy (सुधार कैसे करें)
      1. [Actionable Tip 1 based on errors]
      2. [Actionable Tip 2]
      3. [Actionable Tip 3]
      
      Keep it professional and strict.
      """;

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      return response.text ?? "AI gave an empty response.";

    } catch (e) {
      return "Error: Unable to connect to AI. ($e)";
    }
  }
}
