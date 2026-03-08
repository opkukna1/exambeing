import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'dart:convert'; // JSON parsing ke liye
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

      developer.log("🤖 Generating with Gemini 3.1 Lite...", name: "Exambeing_AI");
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
  // 2. THE BRAIN: AI GENERATION (Daily)
  // =========================================================================
  Future<String> _generateCurrentAffairsFromAI({
    required String dateText,
    required String region,
    required String language,
  }) async {
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      final model = GenerativeModel(
        model: 'gemini-3.1-flash-lite-preview', // 🔥 Sahi Model wapas laga diya 🔥
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
  // 3. AI TEST ENGINE: GENERATE 10 MCQs FROM DAILY NEWS
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
        model: 'gemini-3.1-flash-lite-preview', // 🔥 Sahi Model wapas laga diya 🔥
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

  // =========================================================================
  // 🔥 4. MEGA ENGINE: MONTHLY COMPILATION (MAGAZINE) - GEMINI 2.5 FLASH 🔥
  // =========================================================================
  Future<String> getOrGenerateMonthlyCompilation({
    required DateTime monthDate,
    required String region,
    required String language,
  }) async {
    try {
      String monthKey = DateFormat('yyyy_MM').format(monthDate); 
      String monthName = DateFormat('MMMM yyyy').format(monthDate); 
      String category = "${region}_$language";

      developer.log("📚 Fetching Monthly Magazine: $monthName | $category", name: "Exambeing_Mega");

      DocumentReference monthlyRef = _db.collection('monthly_magazines').doc(monthKey).collection(category).doc('compilation');
      DocumentSnapshot doc = await monthlyRef.get();

      if (doc.exists && doc.data() != null) {
        developer.log("✅ Mega Load: Monthly Magazine found in Firebase!", name: "Exambeing_Mega");
        return doc.get('content');
      }

      developer.log("🤖 Compiling Monthly Magazine from Daily Data...", name: "Exambeing_Mega");

      QuerySnapshot dailyDocs = await _db.collection('current_affairs').doc(monthKey).collection(category).get();
      
      if (dailyDocs.docs.isEmpty) {
        return "🚨 **No Data Found!**\nIs mahine ($monthName) ka daily data available nahi hai. AI compile nahi kar paya.";
      }

      StringBuffer rawMonthData = StringBuffer();
      for (var d in dailyDocs.docs) {
        rawMonthData.writeln("Date: ${d['date']}");
        rawMonthData.writeln(d['content']);
        rawMonthData.writeln("---");
      }

      final apiKey = dotenv.env['GEMINI_API_KEY'];
      final model = GenerativeModel(
        model: 'gemini-2.5-flash', // Yeh 2.5 flash hi rahega Monthly ke liye
        apiKey: apiKey ?? "",
      );

      String prompt = """
      You are the Chief Editor for a Premium UPSC/RPSC Exam Magazine.
      I am providing you with the raw daily current affairs for $region for the entire month of $monthName.
      
      Language Required: $language.

      Your Task:
      1. Compile this into a comprehensive but crisp "Monthly Current Affairs Magazine".
      2. REMOVE all repetitive news. Combine continuing stories into single impactful points.
      3. Categorize the news logically (e.g., State/National News, Schemes & Policies, Awards & Honors, Sports, Appointments, Economy).
      4. Keep the most important exam facts intact. Do not lose crucial dates, numbers, or names.
      5. The output should be extensive (detailed enough for exam prep) but zero fluff. Do not worry about length constraints.
      6. Format strictly in beautiful Markdown with proper headings, bullets, and bold text.

      Raw Month Data:
      $rawMonthData
      """;

      final response = await model.generateContent([Content.text(prompt)]);
      String compiledContent = response.text ?? "Error compiling magazine.";

      if (!compiledContent.startsWith("Error")) {
        await monthlyRef.set({
          'content': compiledContent,
          'createdAt': FieldValue.serverTimestamp(),
          'month': monthName,
          'region': region,
          'language': language,
        });
        developer.log("💾 Monthly Magazine Saved to Firebase!", name: "Exambeing_Mega");
      }

      return compiledContent;

    } catch (e) {
      developer.log("❌ Monthly Compilation Error: $e", name: "Exambeing_Mega");
      return "🚨 Error compiling monthly data. Please check internet. $e";
    }
  }

  // =========================================================================
  // 🔥 5. MEGA ENGINE: MONTHLY 50-MCQ TEST - GEMINI 2.5 FLASH 🔥
  // =========================================================================
  Future<List<dynamic>> getOrGenerateMonthlyTest({
    required DateTime monthDate,
    required String region,
    required String language,
    required String monthlyContent,
  }) async {
    try {
      String monthKey = DateFormat('yyyy_MM').format(monthDate);
      String category = "${region}_$language";

      DocumentReference testRef = _db.collection('monthly_magazines').doc(monthKey).collection(category).doc('mega_test');
      DocumentSnapshot doc = await testRef.get();

      if (doc.exists && doc.data() != null) return doc.get('questions') as List<dynamic>;

      developer.log("🤖 Generating Mega Monthly Test (50 Questions)...", name: "Exambeing_Mega");
      
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      final model = GenerativeModel(
        model: 'gemini-2.5-flash', // Yeh 2.5 flash hi rahega Monthly Test ke liye
        apiKey: apiKey ?? "",
      );

      String prompt = """
      You are an elite Test Creator for UPSC/RPSC exams.
      Create a Mega Mock Test of exactly 50 high-quality Multiple Choice Questions (MCQs) strictly based on the provided Monthly Magazine text.
      Language: $language.
      
      Monthly Magazine Text:
      $monthlyContent

      OUTPUT FORMAT:
      Return ONLY a valid JSON array of objects. No markdown tags, no introduction.
      Format:
      [
        {
          "question": "Question text?",
          "options": ["Opt A", "Opt B", "Opt C", "Opt D"],
          "correctIndex": 0,
          "explanation": "Why?"
        }
      ]
      """;

      final response = await model.generateContent([Content.text(prompt)]);
      String res = response.text!.replaceAll("```json", "").replaceAll("```", "").trim();
      List<dynamic> questions = jsonDecode(res);

      if (questions.isNotEmpty) {
        await testRef.set({'questions': questions, 'createdAt': FieldValue.serverTimestamp()});
        developer.log("💾 Mega Test Saved to Firebase!", name: "Exambeing_Mega");
      }
      return questions;
    } catch (e) {
      developer.log("❌ Mega Test Error: $e", name: "Exambeing_Mega");
      return [];
    }
  }
}
