import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:developer' as developer;

class CurrentAffairsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 🔥 Helper: AI Quota & Error Handler 🔥
  String _handleAIError(Object e) {
    String err = e.toString().toLowerCase();
    if (err.contains('quota') || err.contains('429') || err.contains('exhausted') || err.contains('limit')) {
      return "🚨 **AI Limit Exceeded!**\n\nAI is currently busy due to high traffic. Please try again after 24 hours.";
    }
    return "🚨 **AI Server Error:** $e";
  }

  // =========================================================================
  // 1. ADMIN DRAFT SYSTEM (SAVE & GET RAW TEXT)
  // =========================================================================
  Future<void> saveRawDraft({required DateTime date, required String region, required String rawText}) async {
    String monthKey = DateFormat('yyyy_MM').format(date);
    String dayKey = DateFormat('yyyy_MM_dd').format(date);
    await _db.collection('current_affairs_raw').doc(monthKey).collection(region).doc(dayKey).set({
      'raw_text': rawText,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String> getRawDraft({required DateTime date, required String region}) async {
    String monthKey = DateFormat('yyyy_MM').format(date);
    String dayKey = DateFormat('yyyy_MM_dd').format(date);
    DocumentSnapshot doc = await _db.collection('current_affairs_raw').doc(monthKey).collection(region).doc(dayKey).get();
    if (doc.exists && doc.data() != null && (doc.data() as Map<String, dynamic>).containsKey('raw_text')) {
      return doc.get('raw_text');
    }
    return "";
  }

  // =========================================================================
  // 2. DAILY ENGINE: GET PUBLISHED NEWS
  // =========================================================================
  Future<String> getDailyCurrentAffairs({required DateTime date, required String region, required String language}) async {
    try {
      String monthKey = DateFormat('yyyy_MM').format(date);
      String dayKey = DateFormat('yyyy_MM_dd').format(date);
      String category = "${region}_$language";

      DocumentSnapshot doc = await _db.collection('current_affairs').doc(monthKey).collection(category).doc(dayKey).get();

      if (doc.exists && doc.data() != null && (doc.data() as Map<String, dynamic>).containsKey('content')) {
        return doc.get('content');
      }
      return "NOT_PUBLISHED"; 
    } catch (e) { return "🚨 **Network Error!**\n\n$e"; }
  }

  // =========================================================================
  // 3. 🔥 ADMIN ONLY: GENERATE FROM RAW TEXT (MODEL: 3.1 FLASH LITE) 🔥
  // =========================================================================
  Future<String> generateAndPublishDailyNews({
    required DateTime date, required String region, required String language, required String rawText
  }) async {
    try {
      String exactDateText = DateFormat('dd MMMM yyyy').format(date);
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      // 🔥 LITE MODEL FOR DAILY GENERATION TO SAVE API LIMITS 🔥
      final model = GenerativeModel(model: 'gemini-3.1-flash-lite-preview', apiKey: apiKey ?? ""); 

      String prompt = """
      You are the elite Chief Current Affairs Editor for the "Exambeing" competitive exam app (UPSC/RPSC).
      Target Date: $exactDateText. Target Region: $region. Output Language: $language.

      CRITICAL RULE (ZERO HALLUCINATION):
      Below is raw, unstructured text provided by the Admin.
      1. Extract and format ONLY the news events present in this Raw Text. DO NOT invent, guess, or add any outside news events.
      2. You MAY use your outside knowledge ONLY to add a relevant '🧠 Exam Fact' or '🔗 Static GK Link' at the end of each valid news point.
      3. Translate the raw text into the requested Output Language ($language) accurately.

      FORMATTING RULES:
      - Format strictly as beautiful Markdown. Add a Title: "# Exambeing Daily Current Affairs".
      - Number the points clearly. Use **Bold** for keywords.
      - 📦 SCHEME BOX: If a point is about a Government Scheme or Policy, highlight its core facts using a Markdown blockquote (>).
      - BRANDING: End with "❤️ Curated with love by Exambeing Team".

      RAW TEXT FROM ADMIN:
      $rawText
      """;

      final response = await model.generateContent([Content.text(prompt)]);
      String aiContent = response.text ?? "Error: Empty response";

      if (!aiContent.startsWith("🚨") && !aiContent.startsWith("Error")) {
        String monthKey = DateFormat('yyyy_MM').format(date);
        String dayKey = DateFormat('yyyy_MM_dd').format(date);
        String category = "${region}_$language";
        
        await _db.collection('current_affairs').doc(monthKey).collection(category).doc(dayKey).set({
          'content': aiContent, 'createdAt': FieldValue.serverTimestamp(), 'date': dayKey, 'region': region, 'language': language
        }, SetOptions(merge: true));
      }
      return aiContent;
    } catch (e) { return _handleAIError(e); }
  }

  // =========================================================================
  // 4. DAILY PDF HTML (MODEL: 3.1 FLASH LITE)
  // =========================================================================
  Future<String> getOrGenerateDailyHtml({required DateTime date, required String region, required String language, required String markdownContent}) async {
    try {
      String monthKey = DateFormat('yyyy_MM').format(date); String dayKey = DateFormat('yyyy_MM_dd').format(date); String category = "${region}_$language";
      DocumentReference docRef = _db.collection('current_affairs').doc(monthKey).collection(category).doc(dayKey);
      DocumentSnapshot doc = await docRef.get();
      if (doc.exists && (doc.data() as Map<String, dynamic>).containsKey('htmlContent')) return doc.get('htmlContent'); 

      final apiKey = dotenv.env['GEMINI_API_KEY'];
      // 🔥 LITE MODEL TO SAVE API LIMITS 🔥
      final model = GenerativeModel(model: 'gemini-3.1-flash-lite-preview', apiKey: apiKey ?? "");
      String prompt = "Convert this Markdown to a premium single-page HTML document for A4 PDF printing. DO NOT CHANGE FACTS. Add header '<h1 style=\"color:#5E35B1; text-align:center;\">Exambeing Daily Current Affairs</h1><h3 style=\"text-align:center;\">${DateFormat('dd MMM yyyy').format(date)}</h3>'. Use inline CSS (Main #5E35B1, Highlight #FF9800). Convert blockquotes to <div> boxes with light orange background. End with <center><b>Powered by Exambeing</b></center>. Markdown:\n$markdownContent";
      final response = await model.generateContent([Content.text(prompt)]);
      String htmlOutput = response.text!.replaceAll("```html", "").replaceAll("```", "").trim();
      if (!htmlOutput.startsWith("🚨")) await docRef.set({'htmlContent': htmlOutput}, SetOptions(merge: true));
      return htmlOutput;
    } catch (e) { return "<p style='color:red;'>${_handleAIError(e)}</p>"; }
  }

  // =========================================================================
  // 5. DAILY TEST ENGINE (MODEL: 3.1 FLASH LITE)
  // =========================================================================
  Future<List<dynamic>> getOrGenerateDailyTest({required DateTime date, required String region, required String language, required String newsContent}) async {
    try {
      String monthKey = DateFormat('yyyy_MM').format(date); String dayKey = DateFormat('yyyy_MM_dd').format(date); String category = "${region}_$language";
      DocumentReference testRef = _db.collection('current_affairs_tests').doc(monthKey).collection(category).doc(dayKey);
      DocumentSnapshot doc = await testRef.get();
      if (doc.exists && doc.data() != null) return doc.get('questions') as List<dynamic>;

      final apiKey = dotenv.env['GEMINI_API_KEY'];
      // 🔥 LITE MODEL TO SAVE API LIMITS 🔥
      final model = GenerativeModel(model: 'gemini-3.1-flash-lite-preview', apiKey: apiKey ?? ""); 
      String prompt = 'Create exactly 10 high-level MCQs in valid JSON array strictly from this text. Do NOT use outside knowledge. Format: [{"question": "", "options": ["","","",""], "correctIndex": 0, "explanation": ""}] \nText: $newsContent';
      final response = await model.generateContent([Content.text(prompt)]);
      String res = response.text!.replaceAll("```json", "").replaceAll("```", "").trim();
      List<dynamic> questions = jsonDecode(res);
      if (questions.isNotEmpty) await testRef.set({'questions': questions, 'createdAt': FieldValue.serverTimestamp()});
      return questions;
    } catch (e) { return []; }
  }

  // =========================================================================
  // 6. 🔥 MONTHLY COMPILATION (MODEL: 2.5 FLASH HEAVY DUTY) 🔥
  // =========================================================================
  Future<String> getMonthlyCompilation({required DateTime monthDate, required String region, required String language, required bool isAdmin, bool forceUpdate = false}) async {
    try {
      String monthKey = DateFormat('yyyy_MM').format(monthDate); String monthName = DateFormat('MMMM yyyy').format(monthDate); String category = "${region}_$language";
      DocumentReference monthlyRef = _db.collection('monthly_magazines').doc(monthKey).collection(category).doc('compilation');
      DocumentSnapshot doc = await monthlyRef.get();
      if (!forceUpdate && doc.exists && doc.data() != null && (doc.data() as Map<String, dynamic>).containsKey('content')) return doc.get('content');
      if (!doc.exists && !isAdmin) return "NOT_PUBLISHED";

      QuerySnapshot dailyDocs = await _db.collection('current_affairs').doc(monthKey).collection(category).get();
      if (dailyDocs.docs.isEmpty) return "🚨 No daily data found for $monthName to compile.";

      StringBuffer rawMonthData = StringBuffer();
      for (var d in dailyDocs.docs) { rawMonthData.writeln("Date: ${d['date']}\n${d['content']}\n---"); }

      final apiKey = dotenv.env['GEMINI_API_KEY'];
      // 🔥 2.5 FLASH MODEL FOR HEAVY SUMMARIZATION 🔥
      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey ?? "");
      String prompt = "You are Chief Editor for Exambeing. Create Monthly Magazine for $region ($monthName). Language: $language. BRANDING: '# Exambeing Mega Magazine - $monthName'. FORMAT: beautiful Markdown. CONTENT: Summarize daily data. STRICT RULE: Base summary STRICTLY on 'Raw Month Data'. DO NOT hallucinate. SPECIAL: Highlight schemes in blockquotes (>). Add '❤️ Exambeing'.\nRaw Month Data:\n$rawMonthData";
      final response = await model.generateContent([Content.text(prompt)]);
      String compiledContent = response.text ?? "Error compiling magazine.";
      if (!compiledContent.startsWith("🚨") && !compiledContent.startsWith("Error")) {
        await monthlyRef.set({'content': compiledContent, 'createdAt': FieldValue.serverTimestamp(), 'month': monthName, 'region': region, 'language': language}, SetOptions(merge: true));
      }
      return compiledContent;
    } catch (e) { return _handleAIError(e); }
  }

  // =========================================================================
  // 7. 🔥 MONTHLY HTML FOR PDF (MODEL: 2.5 FLASH HEAVY DUTY) 🔥
  // =========================================================================
  Future<String> getOrGenerateMonthlyHtml({required DateTime monthDate, required String region, required String language, required String markdownContent, required bool forceUpdate}) async {
    try {
      String monthKey = DateFormat('yyyy_MM').format(monthDate); String monthName = DateFormat('MMMM yyyy').format(monthDate); String category = "${region}_$language";
      DocumentReference monthlyRef = _db.collection('monthly_magazines').doc(monthKey).collection(category).doc('compilation');
      DocumentSnapshot doc = await monthlyRef.get();
      if (!forceUpdate && doc.exists && (doc.data() as Map<String, dynamic>).containsKey('htmlContent')) return doc.get('htmlContent'); 

      final apiKey = dotenv.env['GEMINI_API_KEY'];
      // 🔥 2.5 FLASH MODEL FOR LARGE DOCUMENT PARSING 🔥
      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey ?? "");
      String prompt = "Convert Markdown Monthly Magazine to premium single-page HTML for A4 PDF printing. DO NOT CHANGE FACTS. Add header '<h1 style=\"color:#5E35B1; text-align:center;\">Exambeing Mega Magazine - $monthName</h1>'. Styling: inline CSS (#5E35B1, #FF9800). Special: Schemes in <div> boxes. Output ONLY HTML. End with <center><b>❤️ Exambeing</b></center>. Markdown:\n$markdownContent";
      final response = await model.generateContent([Content.text(prompt)]);
      String htmlOutput = response.text!.replaceAll("```html", "").replaceAll("```", "").trim();
      if (!htmlOutput.startsWith("🚨") && !htmlOutput.contains("Error")) await monthlyRef.set({'htmlContent': htmlOutput}, SetOptions(merge: true));
      return htmlOutput;
    } catch (e) { return "<p style='color:red;'>${_handleAIError(e)}</p>"; }
  }

  // =========================================================================
  // 8. 🔥 MEGA MONTHLY TEST (MODEL: 2.5 FLASH HEAVY DUTY) 🔥
  // =========================================================================
  Future<List<dynamic>> getOrGenerateMonthlyTest({required DateTime monthDate, required String region, required String language, required String monthlyContent}) async {
    try {
      String monthKey = DateFormat('yyyy_MM').format(monthDate); String category = "${region}_$language";
      DocumentReference testRef = _db.collection('monthly_magazines').doc(monthKey).collection(category).doc('mega_test');
      DocumentSnapshot doc = await testRef.get();
      if (doc.exists && doc.data() != null) return doc.get('questions') as List<dynamic>;

      final apiKey = dotenv.env['GEMINI_API_KEY'];
      // 🔥 2.5 FLASH MODEL FOR COMPLEX MCQ GENERATION 🔥
      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey ?? ""); 
      String prompt = 'Create EXACTLY 50 MCQs in valid JSON array STRICTLY from this Monthly Magazine text. DO NOT invent facts. Format: [{"question": "", "options": ["","","",""], "correctIndex": 0, "explanation": ""}] \nText: $monthlyContent';
      final response = await model.generateContent([Content.text(prompt)]);
      String res = response.text!.replaceAll("```json", "").replaceAll("```", "").trim();
      List<dynamic> questions = jsonDecode(res);
      if (questions.isNotEmpty) await testRef.set({'questions': questions, 'createdAt': FieldValue.serverTimestamp()});
      return questions;
    } catch (e) { return []; }
  }
}
