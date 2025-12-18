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

  // 🔥 2️⃣ PDF GENERATOR (Professional Layout - NO CUTTING)
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

    // --- 1. HEADER (Fixed Top) ---
    String headerHtml = """
      <div class="pdf-header">
        <span class="brand-text">EXAMBEING</span>
        <span class="page-number"></span>
      </div>
    """;

    // --- 2. PROMOTION PAGE ---
    String promoHtml = """
    <div class="promo-container">
      <div class="promo-inner">
        <header class="promo-header">
            <div class="brand"><i class="fa-solid fa-graduation-cap"></i> Exambeing</div>
            <div class="tagline">Complete Learning Resource</div>
            <div class="main-heading">Every Aspirant's Choice for<br><span style="color: #60a5fa;">Competitive Exams</span></div>
        </header>

        <div class="content">
            <div class="philosophy-box">
                <p><strong>Exambeing</strong> is a technology-driven learning resource for every aspirant.</p>
            </div>
            <div class="features-grid">
                <div class="feature-card"><div class="feature-title">PYQ Test Series</div><div class="feature-desc">Unlimited attempts.</div></div>
                <div class="feature-card"><div class="feature-title">Smart Notes</div><div class="feature-desc">Detailed, Revision, Short.</div></div>
                <div class="feature-card"><div class="feature-title">Analysis</div><div class="feature-desc">Know Strengths & Weaknesses.</div></div>
                <div class="feature-card"><div class="feature-title">Custom Tests</div><div class="feature-desc">Create your own tests.</div></div>
            </div>
        </div>

        <footer>
            <div class="cta-text">
                <h2>Download Now</h2>
                <p>Search "Exambeing" on Google Play</p>
            </div>
        </footer>
      </div>
    </div>
    """;

    // --- CSS STYLING (The Fix) ---
    String css = """
      <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@400;600;700;800&family=Hind:wght@400;600;700&display=swap" rel="stylesheet">
      <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
      <style>
        /* 1. PAGE MARGINS (Critical Fix) */
        @page {
            size: A4;
            /* Top padding for header, Bottom for footer, Side margins minimal (5mm) */
            margin: 15mm 5mm 10mm 5mm; 
        }
        
        /* Remove margin for Cover Page */
        @page:first { margin: 0; }

        body { 
            font-family: 'Poppins', sans-serif; 
            font-size: 12px; /* Increased Font Size */
            color: #222; 
            margin: 0;
            padding: 0;
        }

        /* 2. HEADER (Fixed at Top) */
        .pdf-header {
            position: fixed;
            top: -10mm; /* Adjusted to fit in @page margin */
            left: 0; width: 100%;
            height: 8mm;
            border-bottom: 2px solid #ff4500;
            display: flex; align-items: center; justify-content: space-between;
            padding: 0 5mm;
            background: #fff;
        }
        .brand-text { font-weight: 800; color: #ff4500; font-size: 14px; letter-spacing: 1px; }

        /* 3. COVER PAGE (Full A4) */
        .cover-wrapper {
            position: relative; 
            width: 100vw; height: 100vh; /* Viewport based size */
            background: linear-gradient(135deg, #ffffff 0%, #f0f9ff 100%);
            display: flex; flex-direction: column; justify-content: center; align-items: center;
            text-align: center; border: 8px double #1e40af; 
            box-sizing: border-box;
            z-index: 10;
            background-color: white; /* Hides header on page 1 */
            padding: 20px;
        }
        
        .cover-icon { font-size: 70px; color: #1e40af; margin-bottom: 20px; }
        .label-tag { font-size: 10px; text-transform: uppercase; letter-spacing: 2px; color: #64748b; font-weight: 700; margin-bottom: 5px; display: block; }
        .subject-name { font-size: 26px; font-weight: 700; color: #1e3a8a; margin-bottom: 15px; text-transform: uppercase; }
        .topic-name { font-size: 20px; font-weight: 500; color: #475569; margin-bottom: 25px; }
        .subtopic-box { margin: 20px 0; padding: 15px; background: white; border: 2px dashed #1e40af; border-radius: 10px; width: 90%; }
        .subtopic-name { font-size: 38px; font-weight: 900; color: #1e40af; line-height: 1.1; text-transform: uppercase; }
        .meta-row { display: flex; gap: 10px; justify-content: center; margin-bottom: 50px; margin-top: 20px; }
        .meta-badge { background: #f1f5f9; color: #334155; padding: 5px 15px; border-radius: 5px; font-size: 11px; font-weight: 600; border: 1px solid #cbd5e1; }
        .compiled-by { font-size: 14px; font-weight: 600; color: #334155; margin-bottom: 10px; }
        .copyright-warning { font-size: 9px; color: #dc2626; border-top: 1px solid #dc2626; padding-top: 5px; width: 60%; margin: 0 auto; }

        /* 4. MAIN CONTENT (Split View - Wide) */
        .content-wrapper {
            column-count: 2; 
            column-gap: 6mm; /* Small gap to maximize text area */
            column-rule: 1px solid #ddd;
            text-align: justify; 
            line-height: 1.5;
            padding-top: 5mm;
        }

        /* 🔥 TABLE FIX (The most important part) */
        table {
            width: 100% !important;
            border-collapse: collapse;
            font-size: 11px !important; /* Bigger font for table */
            margin-bottom: 10px;
            table-layout: fixed; /* Ensures column width respects page */
        }
        
        td, th {
            border: 1px solid #888;
            padding: 4px; /* More padding */
            vertical-align: top;
            word-wrap: break-word; /* Wrap long words */
            word-break: break-word; /* Don't chop letters */
            hyphens: auto;
        }
        
        /* Fix list spacing */
        ul, ol { padding-left: 15px; margin: 5px 0; }
        li { margin-bottom: 3px; }

        img { max-width: 100% !important; height: auto; display: block; margin: 5px auto; }

        /* WATERMARK */
        .watermark {
            position: fixed; top: 50%; left: 50%; transform: translate(-50%, -50%) rotate(-45deg);
            font-size: 70px; font-weight: 900; color: rgba(0,0,0,0.04); z-index: -5; pointer-events: none; white-space: nowrap;
        }

        /* 5. PROMO PAGE (Full Sheet) */
        .promo-container {
            page-break-before: always;
            width: 100vw; height: 100vh; /* Full viewport */
            background: white; 
            z-index: 20; 
            position: relative;
            /* Reset any padding from body */
            margin: -15mm -5mm -10mm -5mm; 
        }
        .promo-inner { display: flex; flex-direction: column; height: 100%; border: 1px solid #eee; }
        .promo-header { background: linear-gradient(135deg, #0f172a 0%, #1e3a8a 100%); color: white; padding: 20px; text-align: center; }
        .brand { font-size: 24px; font-weight: 800; color: #fbbf24; margin-bottom: 5px; }
        .content { padding: 20px; flex-grow: 1; }
        .philosophy-box { background: #eff6ff; border-left: 5px solid #2563eb; padding: 10px; margin-bottom: 20px; font-size: 11px; }
        .features-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
        .feature-card { border: 1px solid #e2e8f0; padding: 10px; border-radius: 8px; background: #fff; }
        .feature-title { font-weight: 700; font-size: 11px; color: #1e293b; }
        .feature-desc { font-size: 10px; color: #64748b; }
        footer { background: #0f172a; color: white; padding: 15px; text-align: center; }
      </style>
    """;

    // --- CONSTRUCT HTML ---
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
