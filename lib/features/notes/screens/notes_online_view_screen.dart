import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
// ✅ PDF Packages
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

  // 1️⃣ Database se Content Lana
  Future<void> _fetchContent() async {
    try {
      // Data unpack
      final String subjId = widget.data['subjId'];
      final String subSubjId = widget.data['subSubjId'];
      final String topicId = widget.data['topicId'];
      final String subTopId = widget.data['subTopId'];
      final String lang = widget.data['lang'];
      final String mode = widget.data['mode'];

      // Document ID banana
      final String docId = "${subjId}_${subSubjId}_${topicId}_${subTopId}".toLowerCase();

      // Field Name banana (e.g., detailed_hi)
      final String fieldName = "${mode.toLowerCase().split(' ')[0]}_${lang == 'Hindi' ? 'hi' : 'en'}";

      var doc = await FirebaseFirestore.instance.collection('notes_content').doc(docId).get();

      if (doc.exists && doc.data() != null) {
        var docData = doc.data() as Map<String, dynamic>;
        
        if (docData.containsKey(fieldName) && docData[fieldName].toString().isNotEmpty) {
          setState(() {
            _htmlContent = docData[fieldName];
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = "Content not available for $mode in $lang.";
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = "Content not found in database.";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error: $e";
        _isLoading = false;
      });
    }
  }

  // 🔥 2️⃣ PDF GENERATION LOGIC (Professional Style)
  Future<void> _downloadPdf() async {
    if (_htmlContent == null) return;

    String subjectName = widget.data['displayName'] ?? "Exambeing Notes";
    String mode = widget.data['mode'] ?? "Study";

    // 🎨 CSS STYLING
    String cssStyles = """
      <style>
        @page {
          margin: 20px;
          size: A4;
        }
        body {
          font-family: sans-serif;
          font-size: 12px;
        }
        
        /* COVER PAGE STYLE */
        .cover-page {
          height: 95vh;
          display: flex;
          flex-direction: column;
          justify-content: center;
          align-items: center;
          text-align: center;
          border: 4px double #333;
          padding: 20px;
          margin-bottom: 20px;
          page-break-after: always; /* Force Next Page */
        }
        .main-title {
          font-size: 35px;
          font-weight: bold;
          text-transform: uppercase;
          margin-bottom: 10px;
          color: #000;
        }
        .sub-title {
          font-size: 18px;
          color: #555;
          margin-bottom: 50px;
        }
        .branding {
          font-size: 22px;
          font-weight: bold;
          color: #673AB7; /* Deep Purple */
          margin-top: 100px;
        }
        .copyright {
          font-size: 10px;
          color: red;
          margin-top: 50px;
          border-top: 1px solid red;
          padding-top: 10px;
          width: 80%;
          margin-left: auto;
          margin-right: auto;
        }

        /* SPLIT VIEW (2 COLUMNS) */
        .content-body {
          column-count: 2;
          column-gap: 30px;
          column-rule: 1px solid #ccc; /* Split Line */
          text-align: justify;
          line-height: 1.5;
        }

        /* WATERMARK */
        .watermark {
          position: fixed;
          top: 50%;
          left: 50%;
          transform: translate(-50%, -50%) rotate(-45deg);
          font-size: 60px;
          color: rgba(0, 0, 0, 0.08); /* Light Grey */
          z-index: -1000;
          pointer-events: none;
          white-space: nowrap;
        }
        
        img { max-width: 100%; }
      </style>
    """;

    // 🏗️ HTML STRUCTURE
    String fullHtml = """
      <html>
        <head>$cssStyles</head>
        <body>
          <div class="watermark">Exambeing App</div>

          <div class="cover-page">
             <div style="margin-top: 150px;"></div>
             <div class="main-title">$subjectName</div>
             <div class="sub-title">$mode Mode Notes</div>
             
             <div class="branding">Compiled by<br>Exambeing App 🚀</div>
             
             <div class="copyright">
                ⚠️ <b>COPYRIGHT WARNING</b><br>
                This document is for personal use only. Distribution, copying, or selling this PDF is strictly prohibited and liable to legal action by Exambeing Team.
             </div>
          </div>

          <div class="content-body">
            $_htmlContent
          </div>
        </body>
      </html>
    """;

    // GENERATE PDF
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async {
        return await Printing.convertHtml(
          format: format,
          html: fullHtml,
        );
      },
      name: "${subjectName.replaceAll(' ', '_')}_Exambeing.pdf",
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
          // 📥 PDF Download Button
          if (!_isLoading && _htmlContent != null)
            IconButton(
              icon: const Icon(Icons.download_for_offline),
              tooltip: "Download PDF",
              onPressed: _downloadPdf,
            )
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
