import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'dart:convert'; // Naya import JSON parsing ke liye
import 'dart:developer' as developer;

class CurrentAffairsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // =========================================================================
  // 1. MASTER ENGINE: GET OR GENERATE DAILY CURRENT AFFAIRS
  // =========================================================================
  Future<String> getDailyCurrentAffairs({
    required DateTime date,
    required String region,
    required String language,
  }) async {
    try {
      String monthKey = DateFormat('yyyy_MM').format(date);
      String dayKey = DateFormat('yyyy_MM_dd').format(date);
      String exactDateText = DateFormat('dd MMMM yyyy').format(date);
      String category = "${region}_$language";

      developer.log("🔍 Fetching News: $dayKey | $category", name: "Exambeing_AI");

      DocumentReference docRef = _db
          .collection('current_affairs')
          .doc(monthKey)
          .collection(category)
          .doc(dayKey);

      DocumentSnapshot doc = await docRef.get();

      if (doc.exists && doc.data() != null) {
        developer.log("✅ Load from Firebase (Zero Cost)", name: "Exambeing_AI");
        return doc.get('content');
      }

      developer.log("🤖 Generating with Gemini...", name: "Exambeing_AI");
      String aiContent = await _generateCurrentAffairsFromAI(
        dateText: exactDateText,
        region: region,
        language: language,
      );

      if (!aiContent.startsWith("🚨") && !aiContent.startsWith("Error")) {
        await docRef.set({
          'content': aiContent,
          'createdAt': FieldValue.serverTimestamp(),
          'date': dayKey,
          'region': region,
          'language': language,
        });
        developer.log("💾 Saved to Firebase", name: "Exambeing_AI");
      }

      return aiContent;
    } catch (e) {
      return "🚨 **Network Error!**\n\n$e";
    }
  }

  // =========================================================================
  // 2. THE BRAIN: AI GENERATION (Updated for 10-20 points)
  // =========================================================================
  Future<String> _generateCurrentAffairsFromAI({
    required String dateText,
    required String region,
    required String language,
  }) async {
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      final model = GenerativeModel(
        model: 'gemini-1.5-flash', // Flash model is better for long points
        apiKey: apiKey ?? "",
      );

      String prompt = """
      You are an elite Current Affairs Content Creator for a competitive exam app (UPSC/RPSC).
      Your task is to provide the top 10 to 20 most important Current Affairs for $region on the date: $dateText.

      Language Required: $language.

      CRITICAL INSTRUCTION - USE OFFICIAL SOURCES:
      1. Rajasthan Sujas (DIPR)
      2. PIB India
      3. The Hindu
      4. Dainik Bhaskar

      Format strictly as beautiful Markdown:
      - Add an inspiring Title at the top.
      - Number the 10 to 20 news points clearly.
      - Use **Bold** for keywords, names, schemes, numbers, and important dates.
      - Keep explanations simple, fact-based, and exam-oriented (What, Why, Impact).
      - Add a small '🧠 Exam Fact' or '🔗 Static GK Link' at the end of each point.

      Do not add extra conversational text.
      """;

      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? "Error: Empty response";
    } catch (e) {
      return "🚨 AI Server Error: $e";
    }
  }

  // =========================================================================
  // 3. AI TEST ENGINE: GENERATE 10 MCQs FROM NEWS
  // =========================================================================
  Future<List<dynamic>> getOrGenerateDailyTest({
    required DateTime date,
    required String region,
    required String language,
    required String newsContent,
  }) async {
    try {
      String monthKey = DateFormat('yyyy_MM').format(date);
      String dayKey = DateFormat('yyyy_MM_dd').format(date);
      String category = "${region}_$language";

      DocumentReference testDocRef = _db
          .collection('current_affairs_tests')
          .doc(monthKey)
          .collection(category)
          .doc(dayKey);

      DocumentSnapshot doc = await testDocRef.get();

      if (doc.exists && doc.data() != null) {
        developer.log("✅ Test found in Firebase", name: "Exambeing_Test");
        return doc.get('questions') as List<dynamic>;
      }

      developer.log("🤖 Creating 10 Fresh MCQs...", name: "Exambeing_Test");
      
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      final model = GenerativeModel(
        model: 'gemini-1.5-flash', 
        apiKey: apiKey ?? "",
      );

      String prompt = """
      Create exactly 10 high-level Multiple Choice Questions (MCQs) strictly based on the provided Current Affairs text.
      Language: $language.
      
      News Text:
      $newsContent

      OUTPUT FORMAT:
      Return ONLY a valid JSON array. No markdown tags.
      [
        {
          "question": "Question text here?",
          "options": ["Option A", "Option B", "Option C", "Option D"],
          "correctIndex": 0,
          "explanation": "Why this is correct?"
        }
      ]
      """;

      final response = await model.generateContent([Content.text(prompt)]);
      String res = response.text!.replaceAll("```json", "").replaceAll("```", "").trim();
      List<dynamic> questions = jsonDecode(res);

      if (questions.isNotEmpty) {
        await testDocRef.set({
          'questions': questions,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      return questions;
    } catch (e) {
      developer.log("❌ Test Error: $e");
      return [];
    }
  }
}
