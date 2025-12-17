import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
// ✅ PDF Packages
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
// ✅ TTS Package
import 'package:flutter_tts/flutter_tts.dart';

class NotesOnlineViewScreen extends StatefulWidget {
  final Map<String, dynamic> data;

  const NotesOnlineViewScreen({super.key, required this.data});

  @override
  State<NotesOnlineViewScreen> createState() => _NotesOnlineViewScreenState();
}

class _NotesOnlineViewScreenState extends State<NotesOnlineViewScreen> {
  String? _htmlContent;
  bool _isLoading = true;
  String _errorMessage = "";

  // 🔊 TTS Variables
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _fetchContent();
    _initTts();
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  // 🔊 TTS Logic
  void _initTts() async {
    String langCode = widget.data['lang'] == 'Hindi' ? 'hi-IN' : 'en-US';
    await _flutterTts.setLanguage(langCode);
    await _flutterTts.setSpeechRate(0.5);
    _flutterTts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  Future<void> _toggleReading() async {
    if (_htmlContent == null) return;
    if (_isSpeaking) {
      await _flutterTts.stop();
      if (mounted) setState(() => _isSpeaking = false);
    } else {
      String plainText = _removeHtmlTags(_htmlContent!);
      if (plainText.isNotEmpty) {
        if (mounted) setState(() => _isSpeaking = true);
        await _flutterTts.speak(plainText);
      }
    }
  }

  String _removeHtmlTags(String htmlString) {
    RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    return htmlString.replaceAll(exp, ' ').trim();
  }

  // 1️⃣ Fetch Content
  Future<void> _fetchContent() async {
    try {
      final String subjId = widget.data['subjId'];
      final String subSubjId = widget.data['subSubjId'];
      final String topicId = widget.data['topicId'];
      final String subTopId = widget.data['subTopId'];
      final String lang = widget.data['lang'];
      final String mode = widget.data['mode'];

      final String docId = "${subjId}_${subSubjId}_${topicId}_${subTopId}".toLowerCase();
      final String fieldName = "${mode.toLowerCase().split(' ')[0]}_${lang == 'Hindi' ? 'hi' : 'en'}";

      var doc = await FirebaseFirestore.instance.collection('notes_content').doc(docId).get();

      if (doc.exists && doc.data() != null) {
        var docData = doc.data() as Map<String, dynamic>;
        if (docData.containsKey(fieldName) && docData[fieldName].toString().isNotEmpty) {
          if (mounted) setState(() { _htmlContent = docData[fieldName]; _isLoading = false; });
        } else {
          if (mounted) setState(() { _errorMessage = "Content not available for $mode in $lang."; _isLoading = false; });
        }
      } else {
        if (mounted) setState(() { _errorMessage = "Content not found in database."; _isLoading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _errorMessage = "Error: $e"; _isLoading = false; });
    }
  }

  // 🔥 2️⃣ PDF GENERATOR (Beautiful Cover Page)
  Future<void> _downloadPdf() async {
    if (_htmlContent == null) return;

    // --- Data Extraction ---
    // Agar Subject Name data me nahi hai to generic name use karenge, par koshish karenge nikalne ki
    String subject = widget.data['subjectName'] ?? "Subject / SubSubject"; 
    String topic = widget.data['topicName'] ?? "Topic"; 
    String subtopic = widget.data['displayName'] ?? "Notes"; // Subtopic (File Name)
    
    String mode = widget.data['mode'] ?? "Detailed";
    String lang = widget.data['lang'] ?? "English";
    
    // --- A. HEADER HTML (Fixed) ---
    String headerHtml = """
      <div class="pdf-header">
        <div class="header-brand">
            <i class="fa-solid fa-graduation-cap"></i>
            <span class="brand-text">Exambeing</span>
            <span class="brand-tagline">Complete Learning Resource</span>
        </div>
        <div class="header-cta">
            <i class="fab fa-google-play" style="color: #fff;"></i>
            <div style="display: flex; flex-direction: column; line-height: 1;">
                <span style="font-size: 7px; opacity: 0.8;">Download on</span>
                <span style="font-size: 10px; font-weight: 600;">Google Play</span>
            </div>
        </div>
      </div>
    """;

    // --- B. PROMOTION PAGE HTML ---
    String promoHtml = """
      <div class="promo-page-wrapper">
        <div class="page promo-container">
            <header class="promo-header">
                <div class="brand"><i class="fa-solid fa-graduation-cap"></i> Exambeing</div>
                <div class="tagline">Not Just Coaching, A Complete Learning Resource</div>
                <div class="main-heading">Every Aspirant's Choice for<br><span style="color: #60a5fa;">Competitive Exams</span></div>
            </header>
            <div class="content promo-content">
                <div class="philosophy-box">
                    <p class="hindi-text"><strong>Exambeing</strong> कोई कोचिंग संस्थान या कोर्स बेचने वाला प्लेटफ़ॉर्म नहीं है।<br>यह एक <strong>तकनीक से युक्त शैक्षणिक संसाधन (Learning Resource)</strong> है, जिसे हर प्रतियोगी परीक्षा की तैयारी करने वाले विद्यार्थी को अवश्य उपयोग करना चाहिए।</p>
                </div>
                <div class="features-grid">
                    <div class="feature-card card-1"><div class="feature-icon c1"><i class="fa-solid fa-file-circle-check"></i></div><div class="feature-title">PYQ-Based Test Series</div><div class="feature-desc">Practice Mode & Test Mode available.</div></div>
                    <div class="feature-card card-2"><div class="feature-icon c2"><i class="fa-solid fa-sliders"></i></div><div class="feature-title">Custom Test Creation</div><div class="feature-desc">Select Subject & Topic. Level: Easy/Hard.</div></div>
                    <div class="feature-card card-3"><div class="feature-icon c3"><i class="fa-solid fa-book-open"></i></div><div class="feature-title">3-Layer Notes System</div><div class="feature-desc">1. Detailed Notes<br>2. Revision Notes<br>3. Short Notes</div></div>
                    <div class="feature-card card-4"><div class="feature-icon c4"><i class="fa-solid fa-chart-pie"></i></div><div class="feature-title">Performance Analysis</div><div class="feature-desc">Deep analysis of preparation.</div></div>
                </div>
            </div>
            <footer class="promo-footer">
                <div class="cta-text"><h2>Download Now</h2><p>Take your preparation to the next level.</p></div>
                <div><div class="play-store-badge"><i class="fab fa-google-play fa-lg" style="color: #000;"></i><div style="display: flex; flex-direction: column; line-height: 1;"><span style="font-size: 9px; font-weight: normal;">GET IT ON</span><span style="font-size: 14px;">Google Play</span></div></div></div>
            </footer>
        </div>
      </div>
    """;

    // --- C. CSS STYLING (Sundar Design) ---
    String css = """
      <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;600;700;800&family=Hind:wght@400;600;700&display=swap" rel="stylesheet">
      <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
      <style>
        @page { margin: 0; size: A4; }
        * { box-sizing: border-box; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
        body { font-family: 'Poppins', sans-serif; margin: 0; background: #fff; }

        /* FIXED HEADER */
        .pdf-header {
            position: fixed; top: 0; left: 0; width: 100%; height: 50px;
            background: linear-gradient(90deg, #0f172a 0%, #1e40af 100%);
            color: white; display: flex; align-items: center; justify-content: space-between;
            padding: 0 30px; border-bottom: 3px solid #fbbf24; z-index: 1000;
        }
        .header-brand { display: flex; align-items: center; gap: 10px; }
        .header-brand i { color: #fbbf24; font-size: 20px; }
        .brand-text { font-size: 18px; font-weight: 700; }
        .brand-tagline { font-size: 10px; opacity: 0.9; margin-left: 10px; padding-left: 10px; border-left: 1px solid rgba(255,255,255,0.3); }
        .header-cta { display: flex; align-items: center; gap: 8px; background: rgba(255, 255, 255, 0.1); padding: 4px 12px; border-radius: 20px; border: 1px solid rgba(255, 255, 255, 0.2); }

        /* 🔥 PREMIUM COVER PAGE 🔥 */
        .cover-page {
            position: relative; z-index: 5000; /* Hides Header */
            background: linear-gradient(135deg, #ffffff 0%, #f0f9ff 100%); /* Light Gradient BG */
            width: 100%; height: 297mm; 
            display: flex; flex-direction: column; justify-content: center; align-items: center;
            text-align: center; border: 12px solid #1e40af; 
            padding: 40px;
        }
        
        /* Decorative Corners */
        .corner-deco {
            position: absolute; width: 100px; height: 100px;
            border-style: solid; border-color: #fbbf24;
        }
        .tl { top: 20px; left: 20px; border-width: 5px 0 0 5px; }
        .br { bottom: 20px; right: 20px; border-width: 0 5px 5px 0; }

        /* Logo Area */
        .cover-icon { 
            font-size: 80px; color: #1e40af; margin-bottom: 30px; 
            background: white; padding: 30px; border-radius: 50%;
            box-shadow: 0 10px 25px rgba(30, 64, 175, 0.15);
        }

        /* Hierarchy Text */
        .label-tag {
            font-size: 10px; text-transform: uppercase; letter-spacing: 2px;
            color: #64748b; font-weight: 700; margin-bottom: 5px; display: block;
        }

        .subject-name { font-size: 28px; font-weight: 700; color: #1e3a8a; margin-bottom: 20px; text-transform: uppercase; }
        
        .topic-name { font-size: 22px; font-weight: 500; color: #475569; margin-bottom: 30px; }

        /* Subtopic Highlight Box */
        .subtopic-box {
            background: white; border: 2px dashed #1e40af; 
            padding: 20px 40px; border-radius: 12px;
            margin-bottom: 40px; width: 90%;
            box-shadow: 0 5px 15px rgba(0,0,0,0.05);
        }
        .subtopic-name { font-size: 36px; font-weight: 800; color: #0f172a; line-height: 1.2; }

        /* Meta Badges */
        .meta-row { display: flex; gap: 15px; justify-content: center; margin-bottom: 60px; }
        .meta-badge { background: #1e40af; color: white; padding: 8px 20px; border-radius: 20px; font-size: 12px; font-weight: 600; }
        .meta-badge-outline { border: 2px solid #1e40af; color: #1e40af; padding: 6px 18px; border-radius: 20px; font-size: 12px; font-weight: 700; }

        /* Footer */
        .compiled-by { font-size: 16px; font-weight: 600; color: #334155; margin-bottom: 15px; }
        .copyright-warning { 
            font-size: 11px; color: #dc2626; border-top: 1px solid #dc2626; 
            padding-top: 10px; width: 70%; margin: 0 auto;
        }

        /* MAIN CONTENT */
        .main-content {
            margin-top: 60px; padding: 40px; font-size: 14px; line-height: 1.6; color: #333; min-height: 90vh;
        }
        
        /* PROMO CSS */
        .promo-page-wrapper { page-break-before: always; width: 100%; height: 297mm; background: white; z-index: 5000; position: relative; }
        .promo-container { width: 100%; height: 100%; display: flex; flex-direction: column; border: 1px solid #eee; }
        .promo-header { background: linear-gradient(135deg, #0f172a 0%, #1e3a8a 100%); color: white; padding: 30px 40px; height: 180px; }
        .promo-content { padding: 20px 40px; flex-grow: 1; }
        .promo-footer { background: #0f172a; color: white; padding: 20px 40px; display: flex; align-items: center; justify-content: space-between; height: 120px; margin-top: auto; }
        .brand { font-size: 28px; font-weight: 800; color: #fbbf24; margin-bottom: 5px; }
        .main-heading { font-size: 24px; font-weight: 700; line-height: 1.2; }
        .philosophy-box { background: #eff6ff; border-left: 5px solid #2563eb; padding: 10px 15px; border-radius: 0 8px 8px 0; margin-bottom: 20px; font-size: 12px; }
        .features-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; margin-bottom: 15px; }
        .feature-card { border: 1px solid #e2e8f0; border-radius: 8px; padding: 10px; background: #fff; box-shadow: 0 2px 5px rgba(0,0,0,0.05); }
        .feature-title { font-weight: 700; font-size: 12px; color: #1e293b; }
        .feature-desc { font-size: 10px; color: #64748b; line-height: 1.3; }
        .feature-icon { font-size: 16px; margin-bottom: 5px; }
        .c1 { color: #3b82f6; } .c2 { color: #8b5cf6; } .c3 { color: #f59e0b; } .c4 { color: #10b981; } .c5 { color: #ec4899; }
        .play-store-badge { background: white; color: black; padding: 8px 15px; border-radius: 8px; display: flex; align-items: center; gap: 10px; font-weight: bold; font-size: 14px; }
      </style>
    """;

    // --- D. CONSTRUCT HTML ---
    String finalHtml = """
      <!DOCTYPE html>
      <html>
      <head>$css</head>
      <body>
          $headerHtml

          <div class="cover-page">
              <div class="corner-deco tl"></div>
              <div class="corner-deco br"></div>

              <div class="cover-icon"><i class="fa-solid fa-book-open-reader"></i></div>

              <span class="label-tag">SUBJECT / SUB-SUBJECT</span>
              <div class="subject-name">$subject</div>

              <span class="label-tag">TOPIC</span>
              <div class="topic-name">$topic</div>

              <div class="subtopic-box">
                  <span class="label-tag" style="margin-bottom:10px;">SUBTOPIC / CHAPTER</span>
                  <div class="subtopic-name">$subtopic</div>
              </div>

              <div class="meta-row">
                  <div class="meta-badge">$mode Mode</div>
                  <div class="meta-badge-outline">$lang</div>
              </div>
              
              <div class="compiled-by">
                  Compiled By Exambeing App 🚀
              </div>

              <div class="copyright-warning">
                  ⚠️ COPYRIGHT WARNING<br>
                  All Rights Reserved to Exambeing.<br>
                  This document is strictly for personal use.
              </div>
          </div>

          <div class="main-content">
              $_htmlContent
          </div>

          $promoHtml
      </body>
      </html>
    """;

    // --- 5. GENERATE PDF ---
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async {
        return await Printing.convertHtml(
          format: format,
          html: finalHtml,
        );
      },
      name: "${subtopic.replaceAll(' ', '_')}_Notes.pdf",
    );
  }

  @override
  Widget build(BuildContext context) {
    final String displayName = widget.data['displayName'];
    final String lang = widget.data['lang'];
    final String mode = widget.data['mode'];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(displayName, style: const TextStyle(fontSize: 16)),
            Text("$mode Mode • $lang", style: const TextStyle(fontSize: 12)),
          ],
        ),
        backgroundColor: _getThemeColor(mode),
        foregroundColor: Colors.white,
        actions: [
          if (!_isLoading && _htmlContent != null) ...[
            IconButton(
              icon: Icon(_isSpeaking ? Icons.stop_circle_outlined : Icons.record_voice_over),
              tooltip: _isSpeaking ? "Stop Reading" : "Read Aloud",
              onPressed: _toggleReading,
            ),
            IconButton(
              icon: const Icon(Icons.download_for_offline),
              tooltip: "Download PDF",
              onPressed: _downloadPdf,
            ),
          ]
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? _buildErrorView(_errorMessage)
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: HtmlWidget(
                    _htmlContent!,
                    textStyle: const TextStyle(fontSize: 17, height: 1.6, color: Colors.black87),
                  ),
                ),
    );
  }

  Color _getThemeColor(String mode) {
    if (mode == 'Revision') return Colors.orange.shade700;
    if (mode == 'Short') return Colors.red.shade700;
    return Colors.deepPurple;
  }

  Widget _buildErrorView(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.history_edu, size: 60, color: Colors.grey),
          const SizedBox(height: 10),
          Text(msg, style: const TextStyle(color: Colors.grey, fontSize: 16), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
