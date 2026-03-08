import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:developer' as developer;

class CurrentAffairsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // =========================================================================
  // 1. DAILY ENGINE: GET OR GENERATE HTML NEWS
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

      DocumentReference docRef = _db.collection('current_affairs').doc(monthKey).collection(category).doc(dayKey);
      DocumentSnapshot doc = await docRef.get();

      if (doc.exists && doc.data() != null) {
        developer.log("✅ Load from Firebase (Zero Cost)", name: "Exambeing_AI");
        return doc.get('content');
      }

      developer.log("🤖 Generating Premium HTML Daily News with Gemini 3.1 Lite...", name: "Exambeing_AI");
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
  // 2. THE BRAIN: AI GENERATION (Strict Rules + Premium HTML)
  // =========================================================================
  Future<String> _generateCurrentAffairsFromAI({
    required String dateText,
    required String region,
    required String language,
  }) async {
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      final model = GenerativeModel(
        model: 'gemini-3.1-flash-lite-preview', // 🔥 Daily Fast Model 🔥
        apiKey: apiKey ?? "",
      );

      String prompt = """
      You are the Chief Current Affairs Editor for "Exambeing" App.
      Target Date: $dateText
      Target Region: $region
      Language: $language

      CRITICAL CONTENT RULES:
      1. STRICT DATE: Provide ONLY recent news relevant to $dateText. DO NOT include news from 6 months or 1 year ago.
      2. STRICT REGION: If Region is 'India', ONLY provide National/International news (NO Rajasthan local news). If Region is 'Rajasthan', ONLY provide Rajasthan state news.
      
      FORMATTING RULES (HTML for PDF Export):
      1. Output ONLY pure, valid HTML code. DO NOT wrap the output in ```html. Start with a <div>.
      2. BRANDING: Add a beautiful header containing "Exambeing Daily Current Affairs" and "Date: $dateText".
      3. CSS STYLING: Use inline CSS for a premium look. Use Deep Purple (#5E35B1) for main headings. 
      4. CONTENT: Number the news points. Bold important keywords, dates, and numbers.
      5. SPECIAL BOXES: For every Government Scheme, App launch, or very important fact, place it inside a highlighted <div> box with a light background (e.g., background: #FFF3E0; border-left: 5px solid #FF9800; padding: 10px; margin: 10px 0; border-radius: 5px;).
      """;

      final response = await model.generateContent([Content.text(prompt)]);
      
      // Clean HTML output from markdown codeblocks if AI adds them
      String compiledHtml = response.text!.replaceAll("```html", "").replaceAll("```", "").trim();
      return compiledHtml;
      
    } catch (e) {
      return "🚨 AI Server Error: $e";
    }
  }

  // =========================================================================
  // 3. AI TEST ENGINE: GENERATE 10 MCQs
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

      DocumentReference testDocRef = _db.collection('current_affairs_tests').doc(monthKey).collection(category).doc(dayKey);
      DocumentSnapshot doc = await testDocRef.get();

      if (doc.exists && doc.data() != null) return doc.get('questions') as List<dynamic>;

      developer.log("🤖 Creating 10 Fresh MCQs...", name: "Exambeing_Test");
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      final model = GenerativeModel(model: 'gemini-3.1-flash-lite-preview', apiKey: apiKey ?? "");

      String prompt = """
      Create exactly 10 high-level Multiple Choice Questions (MCQs) based on the text. Language: $language.
      News Text: $newsContent
      OUTPUT FORMAT: Return ONLY a valid JSON array. Format: [{"question": "", "options": ["","","",""], "correctIndex": 0, "explanation": ""}]
      """;

      final response = await model.generateContent([Content.text(prompt)]);
      String res = response.text!.replaceAll("```json", "").replaceAll("```", "").trim();
      List<dynamic> questions = jsonDecode(res);

      if (questions.isNotEmpty) {
        await testDocRef.set({'questions': questions, 'createdAt': FieldValue.serverTimestamp()});
      }
      return questions;
    } catch (e) {
      developer.log("❌ Test Error: $e");
      return [];
    }
  }

  // =========================================================================
  // 🔥 4. MEGA ENGINE: HTML MONTHLY MAGAZINE (ADMIN CONTROLLED) 🔥
  // =========================================================================
  Future<String> getMonthlyCompilation({
    required DateTime monthDate,
    required String region,
    required String language,
    required bool isAdmin,
    bool forceUpdate = false,
  }) async {
    try {
      String monthKey = DateFormat('yyyy_MM').format(monthDate); 
      String monthName = DateFormat('MMMM yyyy').format(monthDate); 
      String category = "${region}_$language";

      developer.log("📚 Fetching Monthly Magazine: $monthName | $category", name: "Exambeing_Mega");

      DocumentReference monthlyRef = _db.collection('monthly_magazines').doc(monthKey).collection(category).doc('compilation');
      DocumentSnapshot doc = await monthlyRef.get();

      // Normal User ke liye, agar published hai toh direct bhejo
      if (!forceUpdate && doc.exists && doc.data() != null) {
        return doc.get('content');
      }

      // Agar published nahi hai aur user Admin nahi hai, toh mna kar do
      if (!doc.exists && !isAdmin) {
        return "NOT_PUBLISHED";
      }

      developer.log("🤖 Admin Compiling HTML Monthly Magazine from Daily Data...", name: "Exambeing_Mega");

      QuerySnapshot dailyDocs = await _db.collection('current_affairs').doc(monthKey).collection(category).get();
      
      if (dailyDocs.docs.isEmpty) {
        return "🚨 **No Data Found!**\nIs mahine ($monthName) ka daily data available nahi hai. AI compile nahi kar paya.";
      }

      StringBuffer rawMonthData = StringBuffer();
      for (var d in dailyDocs.docs) {
        rawMonthData.writeln("Date: ${d['date']}\n${d['content']}\n---");
      }

      final apiKey = dotenv.env['GEMINI_API_KEY'];
      final model = GenerativeModel(
        model: 'gemini-2.5-flash', // 🔥 HIGH CAPACITY MODEL for Monthly 🔥
        apiKey: apiKey ?? "",
      );

      String prompt = """
      You are the Chief Editor for "Exambeing", a Premium UPSC/RPSC Exam Platform.
      Create the Monthly Current Affairs Magazine for $region for the month of $monthName. Language: $language.

      CRITICAL INSTRUCTIONS:
      1. BRANDING: Start with a beautiful header containing "Exambeing Monthly Magazine - $monthName" and "Published by: Exambeing Team".
      2. FORMAT: Output ONLY pure, valid HTML code. DO NOT wrap the output in ```html. Just raw HTML starting with <div>.
      3. CSS STYLING: Use inline CSS for a premium look suitable for A4 PDF printing. Use deep purple (#5E35B1) for main headings.
      4. CONTENT: Summarize the daily data. REMOVE outdated/repetitive news. Divide into clear categories (Polity, Economy, Sports, Awards, Rajasthan Special, etc.).
      5. SPECIAL BOXES: For every major Government Scheme or important fact, put it inside a beautifully highlighted <div> box with a light colored background and a border (e.g., background: #E8EAF6; border-left: 5px solid #3F51B5; padding: 12px; border-radius: 6px; margin-bottom: 10px;).
      
      Raw Month Data:
      $rawMonthData
      """;

      final response = await model.generateContent([Content.text(prompt)]);
      
      String compiledHtml = response.text!.replaceAll("```html", "").replaceAll("```", "").trim();

      if (compiledHtml.isNotEmpty && !compiledHtml.startsWith("Error")) {
        await monthlyRef.set({
          'content': compiledHtml,
          'createdAt': FieldValue.serverTimestamp(),
          'month': monthName,
          'region': region,
          'language': language,
        });
        developer.log("💾 Monthly Magazine Saved to Firebase!", name: "Exambeing_Mega");
      }

      return compiledHtml;

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
        model: 'gemini-2.5-flash', 
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
      }
      return questions;
    } catch (e) {
      developer.log("❌ Mega Test Error: $e", name: "Exambeing_Mega");
      return [];
    }
  }
}
