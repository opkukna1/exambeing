import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart'; // Debug print ke liye

class AiAnalysisService {
  
  // ⚠️ IMPORTANT: Yahan apni asli API Key paste karein.
  // Inverted commas ' ' ke andar honi chahiye.
  static const String _apiKey = 'AIzaSyA2RwvlhdMHLe3r9Ivi592kxYR-IkIbnpQ'; 

  // 1. LIMIT CHECK & UPDATE FUNCTION (5 Times/Month)
  Future<bool> _checkAndIncrementQuota() async {
    try {
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
    } catch (e) {
      debugPrint("Quota Error: $e");
      // Agar DB error aaye, tab bhi user ko analysis karne do (Fallback)
      return true; 
    }
  }

  // 2. FETCH USER PERFORMANCE DATA (Last 10 Tests)
  Future<String> _fetchUserStats() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return "";

      // 'test_results' collection se data lana
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
        
        // Data safety checks (Null handle karne ke liye)
        String topic = data['topicName'] ?? 'Unknown Topic';
        var score = data['score'] ?? 0;
        var total = data['totalQuestions'] ?? 0;
        
        statsData += "- Topic: $topic | Score: $score/$total\n";
      }
      
      return statsData;
    } catch (e) {
      debugPrint("Firebase Fetch Error: $e");
      return "Error fetching data.";
    }
  }

  // 3. MAIN FUNCTION TO CALL GEMINI (AI)
  Future<String> getAnalysis() async {
    
    // Safety Check: API Key check
    if (_apiKey == 'PASTE_YOUR_API_KEY_HERE' || _apiKey.isEmpty) {
      return "Error: API Key is missing inside ai_analysis_service.dart";
    }

    try {
      // A. Check Quota
      bool canUse = await _checkAndIncrementQuota();
      if (!canUse) {
        return "LIMIT_REACHED"; 
      }

      // B. Fetch Data from Firebase
      String userData = await _fetchUserStats();
      if (userData.contains("No test data") || userData.isEmpty) {
        return "NO_DATA";
      }

      // C. Initialize Gemini Model
      final model = GenerativeModel(
        model: 'gemini-pro', 
        apiKey: _apiKey,
      );

      // D. The Prompt (Hindi Response ke liye)
      final prompt = """
      You are an expert Exam Mentor (Coach) for competitive exams like UPSC/SSC. 
      Analyze this student's performance data:
      
      $userData

      Based on this data, provide a structured analysis in **HINDI (Mixed with English terms)**.
      Do NOT use asterisks (*) for bold, strictly use Markdown headers (###).
      
      The response must follow this structure:

      ### 🟢 Strong Areas (मजबूत पक्ष)
      - [List 2-3 topics where score is high]

      ### 🔴 Weak Areas (कमजोर पक्ष)
      - [List 2-3 topics where score is low]

      ### 🔍 Pattern Analysis
      - [Analyze if they are making silly mistakes or lacking conceptual clarity based on scores]

      ### 🚀 Action Plan for Next Week
      1. [Step 1]
      2. [Step 2]
      3. [Step 3]
      
      Keep the tone motivating but professional.
      """;

      // E. Generate Content
      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      
      return response.text ?? "AI gave an empty response. Please try again.";

    } catch (e) {
      // Black screen issues yahan pakdi jayengi
      debugPrint("AI Service Error: $e");
      return "Error: Unable to connect to AI. ($e)";
    }
  }
}
