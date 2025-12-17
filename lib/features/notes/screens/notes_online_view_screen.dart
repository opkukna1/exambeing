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

  // 🔥 ULTIMATE PDF FIX (Table, Header, Blank Page)
  Future<void> _downloadPdf() async {
    if (_htmlContent == null) return;

    // Data Extraction
    String subject = widget.data['subjectName'] ?? ""; 
    String topic = widget.data['topicName'] ?? ""; 
    String subtopic = widget.data['displayName'] ?? "NOTES"; 
    String mode = widget.data['mode'] ?? "";
    String lang = widget.data['lang'] ?? "";

    // HTML Components
    String subjectHtml = subject.isNotEmpty ? '<div class="meta-label">SUBJECT</div><div class="meta-value">$subject</div>' : '';
    String topicHtml = topic.isNotEmpty ? '<div class="meta-label">TOPIC</div><div class="meta-value">$topic</div>' : '';

    String headerHtml = """
      <div class="header-container">
          <div style="font-weight:bold; font-size:16px; display:flex; align-items:center; gap:5px;">
            <span>🎓</span> Exambeing
          </div>
          <div style="font-size:10px; background:rgba(255,255,255,0.2); padding:2px 8px; border-radius:4px;">Google Play</div>
      </div>
    """;

    String promoHtml = """
      <div class="promo-wrapper">
          <div class="promo-header">
             <h1 style="margin:0; font-size:24px;">Exambeing App</h1>
             <p style="margin:5px 0 0 0; opacity:0.8;">Complete Learning Resource</p>
          </div>
          <div class="promo-body">
             <div style="background:#eff6ff; padding:15px; border-left:4px solid #2563eb; margin-bottom:20px;">
                <p style="margin:0; font-size:12px;"><strong>Concept:</strong> Not just coaching, but a technology-driven learning resource.</p>
             </div>
             <h3>Why Exambeing?</h3>
             <ul style="font-size:12px; line-height:1.6;">
                <li><strong>PYQ Test Series:</strong> Practice unlimited times.</li>
                <li><strong>Smart Notes:</strong> 3-Layer System.</li>
                <li><strong>Analysis:</strong> Know your weak areas instantly.</li>
             </ul>
          </div>
          <div class="promo-footer">
             <h2>Download Now</h2>
             <span style="background:white; color:black; padding:5px 10px; border-radius:4px; font-weight:bold; font-size:12px;">Available on Google Play</span>
          </div>
      </div>
    """;

    // --- CSS STYLING (FIXED TABLES) ---
    String css = """
      <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;600;700;800&display=swap" rel="stylesheet">
      <style>
        /* 1. PAGE SETUP */
        @page {
            size: A4;
            margin: 20mm 15mm 15mm 15mm; /* Top margin header ke liye */
        }
        
        /* 🔥 FIX: Cover page margin ZERO to prevent blank page */
        @page:first {
            margin: 0;
        }

        body { font-family: 'Poppins', sans-serif; color: #333; margin: 0; }

        /* 2. HEADER SYSTEM */
        .header-container {
            position: fixed;
            top: -15mm; left: -15mm; right: -15mm; /* Move into margin area */
            height: 15mm;
            background: linear-gradient(90deg, #0f172a 0%, #1e40af 100%);
            color: white;
            display: flex; align-items: center; justify-content: space-between;
            padding: 0 20mm;
            border-bottom: 2px solid #fbbf24;
        }

        /* 3. COVER PAGE (Full Screen) */
        .cover-wrapper {
            width: 100%; height: 297mm;
            display: flex; flex-direction: column; justify-content: center; align-items: center;
            text-align: center;
            background: linear-gradient(135deg, #ffffff 0%, #f0f9ff 100%);
            border: 10px solid #1e40af;
            box-sizing: border-box;
            page-break-after: always;
        }

        .cover-icon { font-size: 80px; color: #1e40af; margin-bottom: 30px; }
        .meta-label { font-size: 10px; color: #64748b; letter-spacing: 2px; font-weight: bold; margin-bottom: 5px; margin-top: 20px; }
        .meta-value { font-size: 24px; color: #1e3a8a; font-weight: 700; text-transform: uppercase; line-height: 1.2; }
        
        .subtopic-box { margin: 40px 0; padding: 20px; background: white; border: 2px dashed #1e40af; border-radius: 10px; width: 80%; }
        .subtopic-text { font-size: 36px; font-weight: 800; color: #0f172a; line-height: 1.1; }

        .compiled-text { margin-top: 60px; font-size: 16px; font-weight: 600; color: #334155; }
        .warning-text { margin-top: 10px; font-size: 10px; color: red; }

        /* 4. CONTENT WRAPPER (Split Columns) */
        .content-wrapper {
            column-count: 2;
            column-gap: 8mm; /* Gap thoda kam kiya */
            column-rule: 1px solid #ccc;
            text-align: justify;
            font-size: 12px;
            line-height: 1.5;
            padding-top: 10px;
        }

        /* 🔥🔥 AGGRESSIVE TABLE FIX 🔥🔥 */
        table {
            width: 100% !important;
            table-layout: fixed !important; /* Force width */
            border-collapse: collapse;
            font-size: 9px; /* Smaller font for tables */
            margin-bottom: 10px;
        }
        
        td, th {
            border: 1px solid #999;
            padding: 3px;
            vertical-align: top;
            
            /* 🔥 FORCE WORD BREAKING */
            word-break: break-all !important; 
            overflow-wrap: anywhere !important; 
            white-space: normal !important;
        }

        /* IMAGES */
        img { max-width: 100% !important; height: auto; display: block; margin: 5px auto; }

        /* WATERMARK */
        .watermark {
            position: fixed; top: 50%; left: 50%; transform: translate(-50%, -50%) rotate(-45deg);
            font-size: 80px; font-weight: 900; color: rgba(0,0,0,0.03); z-index: -10; pointer-events: none;
        }

        /* PROMO PAGE */
        .promo-wrapper {
            page-break-before: always;
            width: 100%; height: 100%;
            border: 1px solid #eee;
            background: white;
            box-sizing: border-box;
            display: flex; flex-direction: column;
        }
        .promo-header { background: #1e3a8a; color: white; padding: 20px; text-align: center; }
        .promo-body { flex-grow: 1; padding: 20px; }
        .promo-footer { background: #0f172a; color: white; padding: 15px; text-align: center; margin-top: auto; }
      </style>
    """;

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
                  <div style="font-size:10px; color:#64748b; font-weight:bold; margin-bottom:5px;">SUBTOPIC / CHAPTER</div>
                  <div class="subtopic-text">$subtopic</div>
              </div>

              <div class="meta-label">MODE / LANGUAGE</div>
              <div style="font-size:14px; font-weight:bold;">$mode • $lang</div>

              <div class="compiled-by">
                 <div class="compiled-text">Compiled By Exambeing App 🚀</div>
                 <div class="warning-text">⚠️ COPYRIGHT WARNING: All Rights Reserved.</div>
              </div>
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
