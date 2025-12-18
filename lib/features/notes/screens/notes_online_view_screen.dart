import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchContent();
  }

  Future<void> _fetchContent() async {
    try {
      final String subjId = widget.data['subjId'];
      final String subSubjId = widget.data['subSubjId'];
      final String topicId = widget.data['topicId'];
      final String subTopId = widget.data['subTopId'];
      final String lang = widget.data['lang'];
      final String mode = widget.data['mode'];

      // Document ID generation logic
      final String docId = "${subjId}_${subSubjId}_${topicId}_${subTopId}".toLowerCase();
      // Field name logic (e.g., theory_en, theory_hi)
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

  // 🔥 FINAL PDF GENERATOR (Header Fixed + Promo Page Perfect)
  Future<void> _downloadPdf() async {
    if (_htmlContent == null) return;

    // Data Extraction for Cover Page
    String subject = widget.data['subjectName'] ?? ""; 
    String topic = widget.data['topicName'] ?? ""; 
    String subtopic = widget.data['displayName'] ?? "NOTES"; 
    String mode = widget.data['mode'] ?? "";
    String lang = widget.data['lang'] ?? "";

    // HTML Components for Cover Page
    String subjectHtml = subject.isNotEmpty ? '<div class="meta-label">SUBJECT</div><div class="subject-name">$subject</div>' : '';
    String topicHtml = topic.isNotEmpty ? '<div class="meta-label">TOPIC</div><div class="topic-name">$topic</div>' : '';

    // --- 1. NEW SIMPLE HEADER (Only Text, Saffron Color) ---
    String headerHtml = """
      <div class="text-header">EXAMBEING</div>
    """;

    // --- 2. PROMO HTML (Marketing Page) ---
    String promoHtml = """
    <div class="promo-container">
      <div class="page promo-page-inner">
        <header class="promo-header">
            <div class="brand"><i class="fa-solid fa-graduation-cap"></i> Exambeing</div>
            <div class="tagline">Not Just Coaching, A Complete Learning Resource</div>
            <div class="main-heading">
                Every Aspirant's Choice for<br>
                <span style="color: #60a5fa;">Competitive Exams</span>
            </div>
        </header>

        <div class="content">
            <div class="philosophy-box">
                <p class="hindi-text">
                    <strong>Exambeing</strong> कोई कोचिंग संस्थान या कोर्स बेचने वाला प्लेटफ़ॉर्म नहीं है।<br>
                    यह एक <strong>तकनीक से युक्त शैक्षणिक संसाधन (Learning Resource)</strong> है, जिसे हर प्रतियोगी परीक्षा की तैयारी करने वाले विद्यार्थी को अवश्य उपयोग करना चाहिए।
                </p>
            </div>

            <div class="features-grid">
                <div class="feature-card card-1">
                    <div class="feature-title">PYQ-Based Test Series</div>
                    <div class="feature-desc">Practice Mode & Test Mode available.<br>Unlimited attempts for perfection.</div>
                </div>
                <div class="feature-card card-2">
                    <div class="feature-title">Custom Test Creation</div>
                    <div class="feature-desc">Select Subject & Topic.<br>Choose Level: Easy / Moderate / Hard.</div>
                </div>
                <div class="feature-card card-3">
                    <div class="feature-title">3-Layer Notes System</div>
                    <div class="feature-desc">1. Detailed Notes<br>2. Revision Notes<br>3. Short Notes (Hindi & English)</div>
                </div>
                <div class="feature-card card-4">
                    <div class="feature-title">Performance Analysis</div>
                    <div class="feature-desc">Deep analysis of your preparation.<br>Know your Strengths & Weaknesses.</div>
                </div>
            </div>

            <div class="feature-card card-5" style="margin-bottom: 20px;">
                <div class="feature-title">Smart Study Tools</div>
                <div class="feature-desc" style="display: flex; gap: 10px; margin-top: 5px;">
                    <span style="background:#fce7f3; padding: 2px 8px; border-radius: 4px; color: #db2777;">Pomodoro</span>
                    <span style="background:#fce7f3; padding: 2px 8px; border-radius: 4px; color: #db2777;">Scheduled Tests</span>
                </div>
            </div>

            <div style="text-align: center; margin-top: 25px;">
                <p class="hindi-text" style="font-size: 16px; font-weight: 600; color: #1e3a8a;">
                    "Exambeing केवल सामग्री नहीं, आपकी मंज़िल का मार्गदर्शक है।"
                </p>
            </div>
        </div>

        <footer>
            <div class="cta-text">
                <h2>Download Now</h2>
                <p>Search "Exambeing" on Google Play.</p>
            </div>
            <div>
                <div class="play-store-badge">
                    <i class="fab fa-google-play fa-lg" style="color: #000;"></i>
                    <div style="display: flex; flex-direction: column; line-height: 1;">
                        <span style="font-size: 9px; font-weight: normal;">GET IT ON</span>
                        <span style="font-size: 14px;">Google Play</span>
                    </div>
                </div>
            </div>
        </footer>
      </div>
    </div>
    """;

    // --- 3. CSS (MARGINS FIXED FOR ALL PAGES) ---
    String css = """
      <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;600;700;800&family=Hind:wght@400;600;700&display=swap" rel="stylesheet">
      <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
      <style>
        /* 1. RESET & PAGE SETUP */
        @page {
            size: A4;
            margin: 0; 
        }

        body { 
            font-family: 'Poppins', sans-serif; 
            margin: 0;
            /* CRITICAL FIX: Main content starts 50px down so it never touches header */
            margin-top: 50px; 
            background: #fff;
            -webkit-print-color-adjust: exact;
        }

        /* 2. NEW TEXT HEADER (Saffron, Top Left) */
        .text-header {
            position: fixed;
            top: 15px;        /* 15px from top */
            left: 25px;       /* 25px from left */
            width: 100%;
            font-size: 14px;
            font-weight: 800; 
            color: #FF5722;   /* SAFFRON COLOR */
            text-transform: uppercase;
            letter-spacing: 1px;
            z-index: 9999;
        }

        /* 3. COVER PAGE (Full Screen Fix) */
        .cover-wrapper {
            position: relative; 
            width: 100%; 
            height: 100vh; 
            background: white; 
            /* FIX: Pull back up by 50px to cover the body margin */
            margin-top: -50px; 
            padding-top: 50px; /* Add internal padding to balance it */
            display: flex; 
            flex-direction: column; 
            justify-content: center; 
            align-items: center;
            text-align: center; 
            border: 15px solid #ff4500;
            box-sizing: border-box;
            z-index: 10000; 
            page-break-after: always;
        }
        
        .cover-brand-big { font-size: 60px; font-weight: 900; color: #ff4500; margin-bottom: 40px; letter-spacing: 2px; }
        .meta-label { font-size: 12px; color: #64748b; letter-spacing: 2px; font-weight: bold; margin-bottom: 5px; margin-top: 30px; }
        .subject-name { font-size: 30px; font-weight: 700; color: #334155; text-transform: uppercase; }
        .topic-name { font-size: 24px; color: #475569; }
        
        .subtopic-box { margin: 50px 0; padding: 20px; width: 90%; border-top: 2px solid #ff4500; border-bottom: 2px solid #ff4500; }
        .subtopic-name { font-size: 45px; font-weight: 900; color: #0f172a; line-height: 1.2; text-transform: uppercase; }
        
        .meta-badge { font-size: 16px; font-weight: bold; background: #ffedd5; color: #c2410c; padding: 8px 20px; border-radius: 30px; margin: 10px; display: inline-block; }
        .compiled-by { margin-top: 60px; font-size: 18px; font-weight: 600; color: #334155; }

        /* 4. CONTENT AREA */
        .content-container {
            /* Standard padding, top spacing handled by body margin */
            padding: 10px 25px 30px 25px; 
            font-size: 16px; 
            line-height: 1.6;
            color: #222;
        }

        /* TABLE STYLING */
        table {
            width: 100% !important;
            border-collapse: collapse;
            font-size: 14px !important; 
            margin-bottom: 15px;
        }
        td, th {
            border: 1px solid #444;
            padding: 8px;
            vertical-align: top;
            word-wrap: break-word;
            word-break: break-word; 
        }
        img { max-width: 100%; height: auto; margin: 10px auto; display: block; }

        /* 5. PROMO PAGE CSS (Layout Fix) */
        .promo-container {
            page-break-before: always;
            width: 210mm; min-height: 297mm;
            background: white;
            z-index: 10001; position: relative;
            /* FIX: Pull promo page up to top edge */
            margin-top: -50px;
        }
        
        .promo-page-inner { width: 100%; height: 297mm; display: flex; flex-direction: column; background: #fff; box-shadow: none; margin: 0; }
        .promo-header { background: linear-gradient(135deg, #0f172a 0%, #1e3a8a 100%); color: white; padding: 30px 40px; clip-path: polygon(0 0, 100% 0, 100% 85%, 0 100%); height: 220px; }
        .brand { font-size: 32px; font-weight: 800; letter-spacing: 1px; margin-bottom: 5px; color: #fbbf24; display: flex; align-items: center; gap: 10px; }
        .tagline { font-size: 16px; opacity: 0.9; font-weight: 300; margin-bottom: 20px; }
        .main-heading { font-size: 28px; font-weight: 700; line-height: 1.2; }
        .content { padding: 10px 40px; flex-grow: 1; }
        .philosophy-box { background: #eff6ff; border-left: 5px solid #2563eb; padding: 15px 20px; border-radius: 0 8px 8px 0; margin-bottom: 25px; margin-top: 10px; }
        .hindi-text { font-family: 'Hind', sans-serif; font-size: 14px; color: #334155; line-height: 1.5; }
        .features-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 15px; margin-bottom: 20px; }
        .feature-card { border: 1px solid #e2e8f0; border-radius: 12px; padding: 15px; background: #fff; position: relative; overflow: hidden; box-shadow: 0 2px 5px rgba(0,0,0,0.05); }
        .feature-card::before { content: ''; position: absolute; top: 0; left: 0; width: 4px; height: 100%; }
        .card-1::before { background: #3b82f6; } .card-2::before { background: #8b5cf6; } .card-3::before { background: #f59e0b; } .card-4::before { background: #10b981; } .card-5::before { background: #ec4899; }
        .feature-title { font-weight: 700; font-size: 14px; margin-bottom: 5px; color: #1e293b; }
        .feature-desc { font-size: 11px; color: #64748b; font-family: 'Hind', sans-serif; line-height: 1.4; }
        footer { background: #0f172a; color: white; padding: 25px 40px; display: flex; align-items: center; justify-content: space-between; height: 160px; }
        .cta-text h2 { font-size: 24px; font-weight: 700; color: #fbbf24; margin-bottom: 5px; }
        .cta-text p { font-size: 14px; color: #cbd5e1; margin-bottom: 15px; }
        .steps { font-size: 12px; display: flex; gap: 15px; }
        .play-store-badge { background: white; color: black; padding: 10px 20px; border-radius: 8px; display: flex; align-items: center; gap: 10px; text-decoration: none; font-weight: bold; font-size: 16px; }
      </style>
    """;

    // --- CONSTRUCT HTML ---
    String finalHtml = """
      <!DOCTYPE html>
      <html>
      <head>$css</head>
      <body>
          $headerHtml

          <div class="cover-wrapper">
              <div class="cover-brand-big">EXAMBEING</div>
              
              $subjectHtml
              $topicHtml

              <div class="subtopic-box">
                  <div class="subtopic-name">$subtopic</div>
              </div>

              <div>
                  <span class="meta-badge">$mode Mode</span>
                  <span class="meta-badge">$lang</span>
              </div>
              
              <div class="compiled-by">Compiled By Exambeing App 🚀</div>
          </div>

          <div class="content-container">
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.data['displayName'] ?? "Notes"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          if (!_isLoading && _htmlContent != null)
            IconButton(
              icon: const Icon(Icons.download_for_offline),
              onPressed: _downloadPdf,
            ),
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
                    textStyle: const TextStyle(fontSize: 17, height: 1.6),
                  ),
                ),
    );
  }
}

