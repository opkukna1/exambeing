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
  // 1. MASTER ENGINE: GET OR GENERATE DAILY CURRENT AFFAIRS (MARKDOWN)
  // =========================================================================
  Future<String> getDailyCurrentAffairs({
    required DateTime date, required String region, required String language,
  }) async {
    try {
      String monthKey = DateFormat('yyyy_MM').format(date);
      String dayKey = DateFormat('yyyy_MM_dd').format(date);
      String exactDateText = DateFormat('dd MMMM yyyy').format(date);
      String category = "${region}_$language";

      developer.log("🔍 Fetching Daily News (Markdown): $dayKey | $category", name: "Exambeing_AI");

      DocumentReference docRef = _db.collection('current_affairs').doc(monthKey).collection(category).doc(dayKey);
      DocumentSnapshot doc = await docRef.get();

      // Agar Markdown pehle se Firebase mein hai, toh direct wahi se do (Zero API call)
      if (doc.exists && doc.data() != null && (doc.data() as Map<String, dynamic>).containsKey('content')) {
        developer.log("✅ Load from Firebase Cache", name: "Exambeing_AI");
        return doc.get('content');
      }

      developer.log("🤖 Generating Premium Markdown News with Gemini 3.1 Lite...", name: "Exambeing_AI");
      String aiContent = await _generateCurrentAffairsFromAI(dateText: exactDateText, region: region, language: language);

      if (!aiContent.startsWith("🚨") && !aiContent.startsWith("Error")) {
        // Merge true lagaya hai taaki htmlContent delete na ho
        await docRef.set({
          'content': aiContent, 'createdAt': FieldValue.serverTimestamp(), 'date': dayKey, 'region': region, 'language': language
        }, SetOptions(merge: true));
      }
      return aiContent;
    } catch (e) { return "🚨 **Network Error!**\n\n$e"; }
  }

  // 🔥 PROMPT FIXED: 15 Points, Exam Facts, Schemes in Box 🔥
  Future<String> _generateCurrentAffairsFromAI({required String dateText, required String region, required String language}) async {
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      final model = GenerativeModel(model: 'gemini-3.1-flash-lite-preview', apiKey: apiKey ?? ""); // Daily Fast Model

      String prompt = """
      You are the elite Chief Current Affairs Editor for the "Exambeing" competitive exam app (UPSC/RPSC).
      Target Date: $dateText. Region: $region. Language: $language.

      CRITICAL CONTENT RULES:
      1. STRICT DATE LIMIT: Provide ONLY fresh news exactly around $dateText. DO NOT provide old news.
      2. STRICT REGION LIMIT: If Region is 'India', strictly provide National & International news ONLY. If Region is 'Rajasthan', strictly provide Rajasthan state news ONLY.
      3. VOLUME: You MUST provide EXACTLY 15 to 20 highly important Current Affairs points.
      4. SOURCES: Rajasthan Sujas (DIPR), PIB India, The Hindu, drishti ias, dainik bhaskar, rajasthan patrika and other.

      FORMATTING RULES:
      - Format strictly as beautiful Markdown. Add a Title: "# Exambeing Daily Current Affairs".
      - Number the 15 to 20 news points clearly. Use **Bold** for keywords, dates, and names.
      - 🧠 EXAM FACT: Add a small '🧠 Exam Fact' or '🔗 Static GK Link' at the end of EACH point.
      - 📦 SCHEME BOX: If a news point is about a Government Scheme, Initiative, App, or Portal, YOU MUST highlight its core facts (Budget, Ministry, Aim, target, objective,dates) using a Markdown blockquote (>) so it looks like a box in the app.
      - BRANDING: End with a nice footer "❤️ Curated with love by Exambeing Team".
      """;
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? "Error: Empty response";
    } catch (e) { return "🚨 AI Server Error: $e"; }
  }

  // =========================================================================
  // 🔥 NEW: GENERATE DAILY HTML FOR PDF (LAZY LOAD - ZERO EXTRA API IF SAVED) 🔥
  // =========================================================================
  Future<String> getOrGenerateDailyHtml({
    required DateTime date, required String region, required String language, required String markdownContent
  }) async {
    try {
      String monthKey = DateFormat('yyyy_MM').format(date);
      String dayKey = DateFormat('yyyy_MM_dd').format(date);
      String category = "${region}_$language";
      DocumentReference docRef = _db.collection('current_affairs').doc(monthKey).collection(category).doc(dayKey);
      
      DocumentSnapshot doc = await docRef.get();
      // Agar pehle kisine PDF banaya tha, toh seedha Firebase se HTML uthao
      if (doc.exists && (doc.data() as Map<String, dynamic>).containsKey('htmlContent')) {
        developer.log("✅ PDF HTML Loaded from Firebase", name: "Exambeing_PDF");
        return doc.get('htmlContent'); 
      }

      developer.log("🎨 Designing Premium HTML for PDF...", name: "Exambeing_PDF");
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      final model = GenerativeModel(model: 'gemini-3.1-flash-lite-preview', apiKey: apiKey ?? "");

      String prompt = """
      Convert the following Markdown Current Affairs into a beautiful, premium, single-page HTML document designed for A4 PDF printing.
      Branding: Add a beautiful header "<h1 style='color:#5E35B1; text-align:center;'>Exambeing Daily Current Affairs</h1><h3 style='text-align:center;'>${DateFormat('dd MMM yyyy').format(date)}</h3>".
      Styling: Use inline CSS. Main color: Deep Purple (#5E35B1). Highlight color: Orange (#FF9800).
      Special Boxes: Convert any blockquotes (schemes) and 'Exam Facts' into beautifully styled <div> boxes with light orange backgrounds (#FFF3E0) and thick left-borders.
      Output ONLY valid HTML code. Do not use ```html tags. End the HTML with "<center><b>Powered by Exambeing</b></center>".
      
      Markdown Content:
      $markdownContent
      """;
      final response = await model.generateContent([Content.text(prompt)]);
      String htmlOutput = response.text!.replaceAll("```html", "").replaceAll("```", "").trim();

      // AI se banwa kar Firebase mein permanently save kar do
      await docRef.set({'htmlContent': htmlOutput}, SetOptions(merge: true));
      return htmlOutput;
    } catch (e) { return "<p>Error generating PDF layout: $e</p>"; }
  }

  // =========================================================================
  // 2. DAILY TEST ENGINE
  // =========================================================================
  Future<List<dynamic>> getOrGenerateDailyTest({required DateTime date, required String region, required String language, required String newsContent}) async {
    try {
      String monthKey = DateFormat('yyyy_MM').format(date); String dayKey = DateFormat('yyyy_MM_dd').format(date); String category = "${region}_$language";
      DocumentReference testRef = _db.collection('current_affairs_tests').doc(monthKey).collection(category).doc(dayKey);
      DocumentSnapshot doc = await testRef.get();
      if (doc.exists && doc.data() != null) return doc.get('questions') as List<dynamic>;

      developer.log("🤖 Creating 10 Fresh MCQs...", name: "Exambeing_Test");
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      final model = GenerativeModel(model: 'gemini-3.1-flash-lite-preview', apiKey: apiKey ?? ""); // Daily Model
      String prompt = 'Create exactly 10 high-level MCQs in valid JSON array from this text. Format: [{"question": "", "options": ["","","",""], "correctIndex": 0, "explanation": ""}] \nText: $newsContent';
      final response = await model.generateContent([Content.text(prompt)]);
      String res = response.text!.replaceAll("```json", "").replaceAll("```", "").trim();
      List<dynamic> questions = jsonDecode(res);
      if (questions.isNotEmpty) await testRef.set({'questions': questions, 'createdAt': FieldValue.serverTimestamp()});
      return questions;
    } catch (e) { return []; }
  }

  // =========================================================================
  // 3. MEGA ENGINE: MONTHLY MAGAZINE (MARKDOWN)
  // =========================================================================
  Future<String> getMonthlyCompilation({
    required DateTime monthDate, required String region, required String language, required bool isAdmin, bool forceUpdate = false,
  }) async {
    try {
      String monthKey = DateFormat('yyyy_MM').format(monthDate); String monthName = DateFormat('MMMM yyyy').format(monthDate); String category = "${region}_$language";
      DocumentReference monthlyRef = _db.collection('monthly_magazines').doc(monthKey).collection(category).doc('compilation');
      DocumentSnapshot doc = await monthlyRef.get();

      if (!forceUpdate && doc.exists && doc.data() != null && (doc.data() as Map<String, dynamic>).containsKey('content')) return doc.get('content');
      if (!doc.exists && !isAdmin) return "NOT_PUBLISHED";

      developer.log("📚 Admin Compiling Monthly Magazine...", name: "Exambeing_Mega");
      QuerySnapshot dailyDocs = await _db.collection('current_affairs').doc(monthKey).collection(category).get();
      if (dailyDocs.docs.isEmpty) return "🚨 No daily data found for $monthName to compile.";

      StringBuffer rawMonthData = StringBuffer();
      for (var d in dailyDocs.docs) { rawMonthData.writeln("Date: ${d['date']}\n${d['content']}\n---"); }

      final apiKey = dotenv.env['GEMINI_API_KEY'];
      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey ?? ""); // 🔥 Monthly Mega Model 🔥

      String prompt = """
      You are the Chief Editor for "Exambeing". Create the Monthly Current Affairs Magazine for $region ($monthName). Language: $language.
      BRANDING: Start with "# Exambeing Mega Magazine - $monthName" and "**Published by: Exambeing Team**".
      FORMAT: Output strictly as beautiful Markdown. Use Headings, bullets, and bold text. NO HTML.
      CONTENT: Summarize daily data. REMOVE outdated/repetitive news. Divide into clear categories (Polity, Economy, Sports,Science and tech,person, etc.).
      SPECIAL: Highlight important schemes and facts using Markdown blockquotes (>). Add "❤️ Exambeing" at the end.
      Raw Month Data: $rawMonthData
      """;
      final response = await model.generateContent([Content.text(prompt)]);
      String compiledContent = response.text ?? "Error compiling magazine.";

      if (!compiledContent.startsWith("Error")) {
        await monthlyRef.set({'content': compiledContent, 'createdAt': FieldValue.serverTimestamp(), 'month': monthName, 'region': region, 'language': language}, SetOptions(merge: true));
      }
      return compiledContent;
    } catch (e) { return "🚨 Error: $e"; }
  }

  // =========================================================================
  // 🔥 GENERATE MONTHLY HTML FOR PDF (LAZY LOAD + ADMIN UPDATE ENABLED) 🔥
  // =========================================================================
  Future<String> getOrGenerateMonthlyHtml({
    required DateTime monthDate, required String region, required String language, required String markdownContent, required bool forceUpdate
  }) async {
    try {
      String monthKey = DateFormat('yyyy_MM').format(monthDate);
      String monthName = DateFormat('MMMM yyyy').format(monthDate);
      String category = "${region}_$language";
      DocumentReference monthlyRef = _db.collection('monthly_magazines').doc(monthKey).collection(category).doc('compilation');
      
      DocumentSnapshot doc = await monthlyRef.get();
      if (!forceUpdate && doc.exists && (doc.data() as Map<String, dynamic>).containsKey('htmlContent')) {
        return doc.get('htmlContent'); 
      }

      developer.log("🎨 Designing Premium Monthly HTML PDF...", name: "Exambeing_PDF");
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey ?? ""); // 🔥 Monthly Mega Model 🔥

      String prompt = """
      Convert the following Markdown Monthly Magazine into a beautiful, premium, single-page HTML document for A4 PDF printing.
      Branding: Add a gorgeous header "<h1 style='color:#5E35B1; text-align:center;'>Exambeing Mega Magazine - $monthName</h1>".
      Styling: Use inline CSS. Main color: Deep Purple (#5E35B1). Highlight color: Orange (#FF9800).
      Special: Put important facts and Schemes in beautifully styled <div> boxes with light backgrounds and borders.
      Output ONLY valid HTML code. Do not use ```html tags. End with <center><b>❤️ Exambeing</b></center>.
      Markdown Content:
      $markdownContent
      """;
      final response = await model.generateContent([Content.text(prompt)]);
      String htmlOutput = response.text!.replaceAll("```html", "").replaceAll("```", "").trim();

      await monthlyRef.set({'htmlContent': htmlOutput}, SetOptions(merge: true));
      return htmlOutput;
    } catch (e) { return "<p>Error generating PDF layout: $e</p>"; }
  }

  // =========================================================================
  // 4. MEGA MONTHLY TEST (50 MCQs)
  // =========================================================================
  Future<List<dynamic>> getOrGenerateMonthlyTest({required DateTime monthDate, required String region, required String language, required String monthlyContent}) async {
    try {
      String monthKey = DateFormat('yyyy_MM').format(monthDate); String category = "${region}_$language";
      DocumentReference testRef = _db.collection('monthly_magazines').doc(monthKey).collection(category).doc('mega_test');
      DocumentSnapshot doc = await testRef.get();
      if (doc.exists && doc.data() != null) return doc.get('questions') as List<dynamic>;

      developer.log("🤖 Generating Mega Monthly Test (50 Questions)...", name: "Exambeing_Mega");
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey ?? ""); // 🔥 Monthly Mega Model 🔥
      String prompt = 'Create EXACTLY 50 MCQs in valid JSON array from this Monthly Magazine text. Format: [{"question": "", "options": ["","","",""], "correctIndex": 0, "explanation": ""}] \nText: $monthlyContent';
      final response = await model.generateContent([Content.text(prompt)]);
      String res = response.text!.replaceAll("```json", "").replaceAll("```", "").trim();
      List<dynamic> questions = jsonDecode(res);
      if (questions.isNotEmpty) await testRef.set({'questions': questions, 'createdAt': FieldValue.serverTimestamp()});
      return questions;
    } catch (e) { return []; }
  }
}
