import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
// ✅ PDF Packages
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
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

  // 🔥 2️⃣ PDF GENERATOR (Clean Cover + Watermark + Split View)
  Future<void> _downloadPdf() async {
    if (_htmlContent == null) return;

    // --- Data Extraction ---
    // Agar naam empty hai to empty string rakhenge taaki print na ho
    String subject = widget.data['subjectName'] ?? ""; 
    String topic = widget.data['topicName'] ?? ""; 
    String subtopic = widget.data['displayName'] ?? "NOTES"; // Ye BADA dikhega
    
    String mode = widget.data['mode'] ?? "";
    String lang = widget.data['lang'] ?? "";

    // HTML Logic for Subject/Topic (Only show if exists)
    String subjectHtml = subject.isNotEmpty ? '<span class="label-tag">SUBJECT</span><div class="subject-name">$subject</div>' : '';
    String topicHtml = topic.isNotEmpty ? '<span class="label-tag">TOPIC</span><div class="topic-name">$topic</div>' : '';
    
    // --- A. FIXED HEADER HTML ---
    String headerHtml = """
      <div class="pdf-header">
        <div class="header-brand">
            <i class="fa-solid fa-graduation-cap"></i>
            <span class="brand-text">Exambeing</span>
        </div>
        <div class="header-cta">
            <span style="font-size: 10px; font-weight: 600;">Google Play</span>
        </div>
      </div>
    """;

    // --- B. PROMOTION PAGE HTML ---
    String promoHtml = """
      <div class="promo-page-wrapper">
        <div class="page promo-container">
            <header class="promo-header">
                <div class="brand"><i class="fa-solid fa-graduation-cap"></i> Exambeing</div>
                <div class="tagline">Complete Learning Resource</div>
                <div class="main-heading">Every Aspirant's Choice for<br><span style="color: #60a5fa;">Competitive Exams</span></div>
            </header>
            <div class="content promo-content">
                <div class="philosophy-box">
                    <p class="hindi-text"><strong>Exambeing</strong> कोई कोचिंग संस्थान नहीं, एक <strong>तकनीक से युक्त शैक्षणिक संसाधन</strong> है।</p>
                </div>
                <div class="features-grid">
                    <div class="feature-card card-1"><div class="feature-title">PYQ-Based Test Series</div><div class="feature-desc">Unlimited attempts.</div></div>
                    <div class="feature-card card-3"><div class="feature-title">3-Layer Notes System</div><div class="feature-desc">Detailed, Revision, Short Notes</div></div>
                </div>
            </div>
            <footer class="promo-footer">
                <div class="cta-text"><h2>Download Now</h2></div>
                <div class="play-store-badge"><i class="fab fa-google-play"></i> Google Play</div>
            </footer>
        </div>
      </div>
    """;

    // --- C. CSS STYLING ---
    String css = """
      <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;600;700;800&family=Hind:wght@400;600;700&display=swap" rel="stylesheet">
      <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
      <style>
        @page { margin: 0; size: A4; }
        * { box-sizing: border-box; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
        body { font-family: 'Poppins', sans-serif; margin: 0; background: #fff; }

        /* WATERMARK (Fixed on all pages) */
        .watermark {
            position: fixed; top: 50%; left: 50%; 
            transform: translate(-50%, -50%) rotate(-45deg);
            font-size: 80px; font-weight: 900;
            color: rgba(0, 0, 0, 0.04); /* Very Light Grey */
            z-index: 0; pointer-events: none; white-space: nowrap;
        }

        /* FIXED HEADER */
        .pdf-header {
            position: fixed; top: 0; left: 0; width: 100%; height: 40px;
            background: linear-gradient(90deg, #0f172a 0%, #1e40af 100%);
            color: white; display: flex; align-items: center; justify-content: space-between;
            padding: 0 30px; border-bottom: 2px solid #fbbf24; z-index: 1000;
        }
        .header-brand { display: flex; align-items: center; gap: 10px; font-weight: bold; font-size: 16px; }
        .header-cta { background: rgba(255,255,255,0.1); padding: 2px 10px; border-radius: 10px; }

        /* COVER PAGE */
        .cover-page {
            position: relative; z-index: 5000; 
            background: white;
            width: 100%; height: 297mm; 
            display: flex; flex-direction: column; justify-content: center; align-items: center;
            text-align: center; border: 10px double #1e40af; 
            padding: 40px;
        }
        .corner-deco { position: absolute; width: 80px; height: 80px; border-style: solid; border-color: #fbbf24; }
        .tl { top: 20px; left: 20px; border-width: 5px 0 0 5px; }
        .br { bottom: 20px; right: 20px; border-width: 0 5px 5px 0; }

        .cover-icon { font-size: 60px; color: #1e40af; margin-bottom: 40px; }

        /* Typography */
        .label-tag { font-size: 10px; letter-spacing: 2px; color: #94a3b8; font-weight: 700; margin-bottom: 5px; display: block; }
        .subject-name { font-size: 24px; font-weight: 700; color: #334155; margin-bottom: 20px; text-transform: uppercase; }
        .topic-name { font-size: 20px; color: #475569; margin-bottom: 30px; }
        
        /* 🔥 BIG SUBTOPIC */
        .subtopic-box {
            padding: 30px 20px; 
            margin-bottom: 60px; width: 100%;
        }
        .subtopic-name { 
            font-size: 45px; /* Huge Size */
            font-weight: 900; 
            color: #1e40af; /* Blue Color */
            line-height: 1.1; 
            text-transform: uppercase;
            text-shadow: 2px 2px 0px #e2e8f0;
        }

        .meta-row { display: flex; gap: 15px; justify-content: center; margin-bottom: 80px; }
        .meta-badge { background: #f1f5f9; color: #334155; padding: 5px 15px; border-radius: 5px; font-size: 12px; font-weight: 600; border: 1px solid #cbd5e1; }

        /* 🔥 BIG COMPILED BY */
        .compiled-by { 
            font-size: 22px; 
            font-weight: 800; 
            color: #0f172a; 
            margin-bottom: 20px; 
            letter-spacing: 1px;
        }
        .copyright-warning { font-size: 10px; color: #ef4444; margin-top: 10px; }

        /* MAIN CONTENT */
        .main-content {
            margin-top: 60px; padding: 0 40px; 
            min-height: 90vh; position: relative; z-index: 1;
            column-count: 2; column-gap: 40px; column-rule: 1px solid #e2e8f0;
            text-align: justify; font-size: 13px; line-height: 1.6;
        }
        
        /* PROMO CSS (Simplified) */
        .promo-page-wrapper { page-break-before: always; width: 100%; height: 297mm; background: white; z-index: 5000; position: relative; }
        .promo-header { background: #1e3a8a; color: white; padding: 30px; height: 150px; }
        .promo-content { padding: 30px; }
        .features-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 15px; margin-top: 20px; }
        .feature-card { border: 1px solid #eee; padding: 15px; border-radius: 8px; }
        .feature-title { font-weight: bold; font-size: 12px; }
        .feature-desc { font-size: 10px; color: #666; }
        .promo-footer { background: #0f172a; color: white; padding: 20px; margin-top: 100px; display: flex; justify-content: space-between; align-items: center; }
        .play-store-badge { background: white; color: black; padding: 5px 15px; border-radius: 5px; font-weight: bold; font-size: 12px; }
      </style>
    """;

    // --- D. CONSTRUCT HTML ---
    String finalHtml = """
      <!DOCTYPE html>
      <html>
      <head>$css</head>
      <body>
          <div class="watermark">Exambeing</div>

          $headerHtml

          <div class="cover-page">
              <div class="corner-deco tl"></div>
              <div class="corner-deco br"></div>

              <div class="cover-icon"><i class="fa-solid fa-book-open"></i></div>

              $subjectHtml
              $topicHtml

              <div class="subtopic-box">
                  <div class="subtopic-name">$subtopic</div>
              </div>

              <div class="meta-row">
                  <div class="meta-badge">$mode Mode</div>
                  <div class="meta-badge">$lang</div>
              </div>
              
              <div class="compiled-by">
                  Compiled By Exambeing App 🚀
              </div>

              <div class="copyright-warning">
                  ⚠️ COPYRIGHT WARNING: All Rights Reserved to Exambeing.
              </div>
          </div>

          <div class="main-content">
              $_htmlContent
          </div>

          $promoHtml
      </body>
      </html>
    """;

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
    final String displayName = widget.data['displayName'] ?? "Notes";
    final String lang = widget.data['lang'] ?? "Eng";
    final String mode = widget.data['mode'] ?? "Detailed";

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(displayName, style: const TextStyle(fontSize: 16)),
            Text("$mode Mode • $lang", style: const TextStyle(fontSize: 12)),
          ],
        ),
        backgroundColor: Colors.deepPurple,
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
              ? Center(child: Text(_errorMessage))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: HtmlWidget(
                    _htmlContent!,
                    textStyle: const TextStyle(fontSize: 17, height: 1.6, color: Colors.black87),
                  ),
                ),
    );
  }
}
