import 'dart:convert'; // JSON decoding
import 'package:http/http.dart' as http; // HTTP package
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

class AiAnalysisService {
  
  // ⚠️ API KEY
  static const String _apiKey = 'AIzaSyA2RwvlhdMHLe3r9Ivi592kxYR-IkIbnpQ'; 
  
  // ✅ FINAL FIX: 'gemini-pro' use kar rahe hain.
  // Yeh Model sabse reliable hai aur 404 error nahi deta.
  static const String _apiUrl = 
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent';

  // 1. LIMIT CHECK
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
      return true; 
    }
  }

  // 2. FETCH DATA
  Future<String> _fetchUserStats() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return "";

      final query = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('test_results')
          .orderBy('timestamp', descending: true)
          .limit(15) 
          .get();

      if (query.docs.isEmpty) return "No test data available.";

      String statsData = "Here is the detailed log of recent questions attempted by the student:\n\n";
      int totalQuestionsRead = 0;

      for (var doc in query.docs) {
        final data = doc.data();
        String topic = data['topicName'] ?? "General";
        List<dynamic> logs = data['logs'] ?? [];

        if (logs.isEmpty) {
          var score = data['score'] ?? 0;
          statsData += "- Old Test ($topic): Score $score\n";
          continue;
        }

        for (var log in logs) {
          if (totalQuestionsRead >= 60) break; 
          String q = log['q'] ?? "";
          String u = log['u'] ?? ""; 
          String c = log['c'] ?? ""; 
          bool s = log['s'] ?? false; 

          statsData += """
          [Topic: $topic]
          Q: $q
          User: $u | Correct: $c | Result: ${s ? "PASS" : "FAIL"}
          -------------------------
          """;
          totalQuestionsRead++;
        }
      }
      return statsData;
    } catch (e) {
      return "Error fetching data.";
    }
  }

  // 3. CALL GEMINI (REST API)
  Future<String> _callGeminiRestApi(String prompt) async {
    try {
      final url = Uri.parse('$_apiUrl?key=$_apiKey');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [{
            "parts": [{"text": prompt}]
          }]
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        String? resultText = jsonResponse['candidates']?[0]?['content']?['parts']?[0]?['text'];
        return resultText ?? "AI returned empty response.";
      } else {
        debugPrint("API Error: ${response.statusCode} - ${response.body}");
        return "Server Error (${response.statusCode}). Try again later.";
      }
    } catch (e) {
      return "Network Error: Check Internet.";
    }
  }

  // 4. MAIN FUNCTION
  Future<String> getAnalysis() async {
    if (_apiKey.isEmpty) return "Error: API Key is missing.";

    try {
      bool canUse = await _checkAndIncrementQuota();
      if (!canUse) return "LIMIT_REACHED";

      String userData = await _fetchUserStats();
      if (userData.contains("No test data")) return "NO_DATA";

      final prompt = """
      You are an elite Exam Coach. I am providing you with a log of the student's recent questions.
      
      DATA:
      $userData

      Analyze the QUESTIONS TEXT and ERRORS deeply.
      Response should be in **HINDI (Hinglish)** and STRICTLY follow this Markdown format:

      ### 📊 Performance Summary
      - **Consistency:** (Check if they are improving or failing randomly)
      - **Topics:** (Mention subjects found)

      ### 🔴 Weak Areas (कमजोर पक्ष)
      - [Identify specific topics/question types where result is FAIL]

      ### 🟢 Strong Areas (मजबूत पक्ष)
      - [Identify topics where result is PASS]

      ### 💡 Smart Strategy (सुधार कैसे करें)
      1. [Actionable Tip 1 based on errors]
      2. [Actionable Tip 2]
      3. [Actionable Tip 3]
      
      Keep it professional.
      """;

      return await _callGeminiRestApi(prompt);

    } catch (e) {
      return "Error: Unexpected issue ($e)";
    }
  }
}
