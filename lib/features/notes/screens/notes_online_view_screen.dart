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

  // 🔥 FINAL PDF GENERATOR
  Future<void> _downloadPdf() async {
    if (_htmlContent == null) return;

    // Data Extraction
    String subject = widget.data['subjectName'] ?? ""; 
    String topic = widget.data['topicName'] ?? ""; 
    String subtopic = widget.data['displayName'] ?? "NOTES"; 
    String mode = widget.data['mode'] ?? "";
    String lang = widget.data['lang'] ?? "";

    String subjectHtml = subject.isNotEmpty ? '<span class="label-tag">SUBJECT</span><div class="subject-name">$subject</div>' : '';
    String topicHtml = topic.isNotEmpty ? '<span class="label-tag">TOPIC</span><div class="topic-name">$topic</div>' : '';

    // --- 1. USER'S HEADER HTML ---
    String headerHtml = """
      <div class="pdf-header">
        <span class="brand-text">EXAMBEING</span>
      </div>
    """;

    // --- 2. USER'S PROMO PAGE HTML (Exactly as provided) ---
    String promoHtml = """
    <div class="promo-wrapper-outer">
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
                    <div class="feature-icon c1"><i class="fa-solid fa-file-circle-check"></i></div>
                    <div class="feature-title">PYQ-Based Test Series</div>
                    <div class="feature-desc">Practice Mode & Test Mode available.<br>Unlimited attempts for perfection.</div>
                </div>
                <div class="feature-card card-2">
                    <div class="feature-icon c2"><i class="fa-solid fa-sliders"></i></div>
                    <div class="feature-title">Custom Test Creation</div>
                    <div class="feature-desc">Select Subject & Topic.<br>Choose Level: Easy / Moderate / Hard.</div>
                </div>
                <div class="feature-card card-3">
                    <div class="feature-icon c3"><i class="fa-solid fa-book-open"></i></div>
                    <div class="feature-title">3-Layer Notes System</div>
                    <div class="feature-desc">1. Detailed Notes<br>2. Revision Notes<br>3. Short Notes (Hindi & English)</div>
                </div>
                <div class="feature-card card-4">
                    <div class="feature-icon c4"><i class="fa-solid fa-chart-pie"></i></div>
                    <div class="feature-title">Performance Analysis</div>
                    <div class="feature-desc">Deep analysis of your preparation.<br>Know your Strengths & Weaknesses.</div>
                </div>
            </div>

            <div class="feature-card card-5" style="margin-bottom: 20px;">
                <div class="feature-icon c5"><i class="fa-solid fa-brain"></i></div>
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
            
            <div style="text-align: center; margin-top: 15px; opacity: 0.1;">
                <i class="fa-solid fa-mobile-screen-button" style="font-size: 70px; color: #000;"></i>
            </div>
        </div>

        <footer>
            <div class="cta-text">
                <h2>Download Now</h2>
                <p>Take your preparation to the next level.</p>
                <div class="steps">
                    <div class="step-item"><i class="fa-solid fa-magnifying-glass"></i> Search "Exambeing"</div>
                    <div class="step-item"><i class="fa-solid fa-download"></i> Install App</div>
                </div>
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

    // --- CSS STYLING ---
    String css = """
      <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;600;700;800&family=Hind:wght@400;600;700&display=swap" rel="stylesheet">
      <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
      <style>
        /* 1. PAGE SETUP (Reduced Side Margins) */
        @page {
            size: A4;
            /* Top 20mm (Header ke liye), Bottom 15mm, Left/Right 10mm (Kam kar diya) */
            margin: 20mm 10mm 15mm 10mm; 
        }
        @page:first { margin: 0; } /* Cover page full bleed */

        body { font-family: 'Poppins', sans-serif; color: #333; margin: 0; }

        /* 2. HEADER CSS (User Provided) */
        .pdf-header {
            position: fixed;
            top: -15mm; /* Moves up into margin */
            left: 0;
            width: 100%;
            height: 12mm; /* Compact height */
            background: #fff;
            border-bottom: 2px solid #ff4500;
            display: flex;
            align-items: center;
            padding-left: 0px;
            z-index: 9999;
        }
        .brand-text {
            font-family: 'Poppins', sans-serif;
            font-size: 18px;
            font-weight: 800;
            color: #ff4500;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            line-height: 1;
        }

        /* 3. COVER PAGE CSS */
        .cover-wrapper {
            position: relative; z-index: 5000; 
            background: linear-gradient(135deg, #ffffff 0%, #f0f9ff 100%);
            width: 210mm; height: 297mm; 
            margin-top: -20mm; margin-left: -10mm; margin-right: -10mm; /* Negative margins to compensate @page */
            display: flex; flex-direction: column; justify-content: center; align-items: center;
            text-align: center; border: 10px double #1e40af; 
            padding: 40px;
            page-break-after: always;
        }
        .cover-icon { font-size: 80px; color: #1e40af; margin-bottom: 30px; }
        .label-tag { font-size: 10px; text-transform: uppercase; letter-spacing: 2px; color: #64748b; font-weight: 700; margin-bottom: 5px; display: block; }
        .subject-name { font-size: 28px; font-weight: 700; color: #1e3a8a; margin-bottom: 20px; text-transform: uppercase; }
        .topic-name { font-size: 22px; font-weight: 500; color: #475569; margin-bottom: 30px; }
        .subtopic-box { margin: 40px 0; padding: 20px; background: white; border: 2px dashed #1e40af; border-radius: 10px; width: 80%; }
        .subtopic-name { font-size: 40px; font-weight: 900; color: #1e40af; line-height: 1.1; text-transform: uppercase; }
        .meta-row { display: flex; gap: 15px; justify-content: center; margin-bottom: 80px; }
        .meta-badge { background: #f1f5f9; color: #334155; padding: 5px 15px; border-radius: 5px; font-size: 12px; font-weight: 600; border: 1px solid #cbd5e1; }
        .compiled-by { font-size: 16px; font-weight: 600; color: #334155; margin-bottom: 15px; }
        .copyright-warning { font-size: 10px; color: #dc2626; border-top: 1px solid #dc2626; padding-top: 10px; width: 70%; margin: 0 auto; }

        /* 4. MAIN CONTENT (Split View) */
        .content-wrapper {
            position: relative; z-index: 1;
            column-count: 2; 
            column-gap: 8mm;
            column-rule: 1px solid #e2e8f0;
            text-align: justify; 
            font-size: 12px; 
            line-height: 1.5;
            padding-top: 5mm; 
        }

        /* 🔥🔥🔥 STRICT TABLE FIX (NO CUTTING) 🔥🔥🔥 */
        table {
            width: 100% !important;
            table-layout: fixed !important; /* Force width constraint */
            border-collapse: collapse;
            font-size: 9px; 
            margin-bottom: 10px;
        }
        
        td, th {
            border: 1px solid #999;
            padding: 3px;
            vertical-align: top;
            
            /* FORCE WORD BREAKING */
            word-break: break-all !important; 
            overflow-wrap: anywhere !important; 
            white-space: normal !important;
        }
        
        img { max-width: 100% !important; height: auto; display: block; margin: 5px auto; }

        /* WATERMARK */
        .watermark {
            position: fixed; top: 50%; left: 50%; transform: translate(-50%, -50%) rotate(-45deg);
            font-size: 80px; font-weight: 900; color: rgba(0,0,0,0.04); z-index: -10; pointer-events: none; white-space: nowrap;
        }

        /* 5. PROMO PAGE CSS (User Provided Adjusted) */
        .promo-wrapper-outer {
            page-break-before: always;
            /* Negative margins to break out of page margins and fill A4 */
            margin-top: -20mm; margin-left: -10mm; margin-right: -10mm;
            width: 210mm; height: 297mm;
            background: white; 
            z-index: 5000; position: relative;
        }
        .promo-page-inner {
            width: 100%; height: 100%;
            display: flex; flex-direction: column;
            background: #f0f0f0; 
        }
        /* Header Design */
        header.promo-header {
            background: linear-gradient(135deg, #0f172a 0%, #1e3a8a 100%);
            color: white; padding: 30px 40px; clip-path: polygon(0 0, 100% 0, 100% 85%, 0 100%); height: 220px;
        }
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
        
        .feature-icon { font-size: 20px; margin-bottom: 8px; }
        .c1 { color: #3b82f6; } .c2 { color: #8b5cf6; } .c3 { color: #f59e0b; } .c4 { color: #10b981; } .c5 { color: #ec4899; }
        
        .feature-title { font-weight: 700; font-size: 14px; margin-bottom: 5px; color: #1e293b; }
        .feature-desc { font-size: 11px; color: #64748b; font-family: 'Hind', sans-serif; line-height: 1.4; }
        
        footer { background: #0f172a; color: white; padding: 25px 40px; display: flex; align-items: center; justify-content: space-between; height: 160px; }
        .cta-text h2 { font-size: 24px; font-weight: 700; color: #fbbf24; margin-bottom: 5px; }
        .cta-text p { font-size: 14px; color: #cbd5e1; margin-bottom: 15px; }
        .steps { font-size: 12px; display: flex; gap: 15px; }
        .step-item { display: flex; align-items: center; gap: 5px; }
        .play-store-badge { background: white; color: black; padding: 10px 20px; border-radius: 8px; display: flex; align-items: center; gap: 10px; text-decoration: none; font-weight: bold; font-size: 16px; }
      </style>
    """;

    // --- CONSTRUCT FINAL HTML ---
    String finalHtml = """
      <!DOCTYPE html>
      <html>
      <head>$css</head>
      <body>
          <div class="watermark">Exambeing</div>

          $headerHtml

          <div class="cover-wrapper">
              <div class="cover-icon">📖</div>
              $subjectHtml
              $topicHtml
              <div class="subtopic-box">
                  <div class="subtopic-name">$subtopic</div>
              </div>
              <div class="meta-row">
                  <div class="meta-badge">$mode Mode</div>
                  <div class="meta-badge">$lang</div>
              </div>
              <div class="compiled-by">Compiled By Exambeing App 🚀</div>
              <div class="copyright-warning">⚠️ COPYRIGHT WARNING: All Rights Reserved.</div>
          </div>

          <div class="content-wrapper">
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
