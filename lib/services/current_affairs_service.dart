import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as developer; // Premium logging ke liye

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
      // 📝 Step A: Unique ID format banana (e.g., "2026_03" aur "2026_03_01")
      String monthKey = DateFormat('yyyy_MM').format(date);
      String dayKey = DateFormat('yyyy_MM_dd').format(date);
      String exactDateText = DateFormat('dd MMMM yyyy').format(date);
      String category = "${region}_$language";

      developer.log("🔍 Fetching Current Affairs for: $dayKey | Category: $category", name: "Exambeing_AI");

      // 📝 Step B: Firebase Database Check karna (SMART CACHING)
      DocumentReference docRef = _db
          .collection('current_affairs')
          .doc(monthKey)
          .collection(category)
          .doc(dayKey);

      DocumentSnapshot doc = await docRef.get();

      // Agar data pehle se hai, toh 1 second mein return kar do (API Bill Bachao!)
      if (doc.exists && doc.data() != null) {
        developer.log("✅ Superfast Load: Data found in Firebase (Zero AI Cost!)", name: "Exambeing_AI");
        return doc.get('content');
      }

      // 📝 Step C: Data nahi mila toh Elite AI se Generate karwao
      developer.log("🤖 Data not found. Waking up Gemini AI Mentor...", name: "Exambeing_AI");
      String aiContent = await _generateCurrentAffairsFromAI(
        dateText: exactDateText,
        region: region,
        language: language,
      );

      // 📝 Step D: AI ne badhiya data diya toh use Firebase par Save (Cache) kar do
      // Taaki din bhar aane wale baaki 1 lakh students ko direct Firebase se data mile
      if (!aiContent.startsWith("🚨") && !aiContent.startsWith("Error")) {
        await docRef.set({
          'content': aiContent,
          'createdAt': FieldValue.serverTimestamp(),
          'date': dayKey,
          'region': region,
          'language': language,
        });
        developer.log("💾 Success: AI Data strictly cached in Firebase!", name: "Exambeing_AI");
      }

      return aiContent;

    } catch (e) {
      developer.log("❌ CRITICAL ERROR in getDailyCurrentAffairs: $e", name: "Exambeing_AI", error: e);
      return "🚨 **Network Error!**\n\nCurrent affairs load karne mein samasya aayi. Kripya apna internet connection check karein.\n\n*Tech Details: $e*";
    }
  }


  // =========================================================================
  // 2. THE BRAIN: GEMINI AI GENERATION LOGIC
  // =========================================================================
  Future<String> _generateCurrentAffairsFromAI({
    required String dateText,
    required String region,
    required String language,
  }) async {
    try {
      // 🔑 Secret Key load karna
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        return "🚨 **Configuration Error!**\nAI API Key is missing. Please contact Admin.";
      }

      // 🧠 Model Setup (Fastest Model for Reading APIs)
      final model = GenerativeModel(
        model: 'gemini-3.1-flash-lite-preview', 
        apiKey: apiKey,
      );

      // 🔥 ELITE PROMPT FOR UPSC/RPSC LEVEL CONTENT 🔥
      String prompt = """
      You are an elite Current Affairs Content Creator for a competitive exam app (UPSC/RPSC).
      Your task is to provide the top 5 most important Current Affairs for $region on the date: $dateText.

      Language Required: $language.

      CRITICAL INSTRUCTION - USE OFFICIAL SOURCES:
      You must strictly curate the news based on the tone, facts, and updates provided by the following official sources:
      1. Rajasthan Sujas (DIPR Orders) - https://dipr.rajasthan.gov.in/department-order/85/10/2583?lan=en
      2. DIPR Rajasthan Press Releases - https://dipr.rajasthan.gov.in/press-release-list/85
      3. PIB India - https://www.pib.gov.in/indexm.aspx?reg=3&lang=2
      4. The Hindu Editorial & National News - https://epaper.thehindu.com/reader
      5. Dainik Bhaskar (For local significant events)

      Format strictly as beautiful Markdown:
      - Add an inspiring Title at the top (e.g., 📰 **Today's Elite Current Affairs**).
      - Number the 10 to 20  news points clearly.
      - Use **Bold** for important keywords, names, schemes, and budget numbers,important dates.
      - Keep explanations simple, fact-based, and exam-oriented (What, Why, Impact).
      - Add a small '🧠 Exam Fact' or '🔗 Static GK Link' at the end of each point (Highly important for RPSC/UPSC).

      Do not add extra conversational text. Give pure, highly valuable exam content that renders beautifully in Flutter Markdown.
      """;

      // AI ko request bhejna
      final response = await model.generateContent([Content.text(prompt)]);
      
      if (response.text == null || response.text!.isEmpty) {
         return "🚨 **AI Error!**\nBackend generated an empty response. Please try again later.";
      }

      return response.text!;

    } catch (e) {
      developer.log("❌ GEMINI API ERROR: $e", name: "Exambeing_AI", error: e);
      return "🚨 **AI Server Error!**\n\nAI se connect nahi ho paya. $e";
    }
  }
}
