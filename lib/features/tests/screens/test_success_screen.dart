import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart'; // 🔥 MASTER PACKAGE FOR PDF
import 'package:pdf/pdf.dart'; // Formats
import 'package:pdf/widgets.dart' as pw; 
import 'package:exambeing/models/question_model.dart';

class TestSuccessScreen extends StatefulWidget {
  final List<Question>? questions;
  final String? topicName;
  final Map<String, dynamic>? data;

  const TestSuccessScreen({
    super.key,
    this.questions,
    this.topicName,
    this.data,
  });

  @override
  State<TestSuccessScreen> createState() => _TestSuccessScreenState();
}

class _TestSuccessScreenState extends State<TestSuccessScreen> {
  late List<Question> finalQuestions;
  late String finalTopicName;
  bool isGenerating = false;

  // --- ADMIN INPUTS ---
  final TextEditingController _examNameController = TextEditingController(text: "MOCK TEST SERIES");
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _durationController = TextEditingController(text: "60 Mins");
  final TextEditingController _marksController = TextEditingController();
  final TextEditingController _watermarkController = TextEditingController(text: "EXAMBEING");
  
  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    if (widget.questions != null) {
      finalQuestions = widget.questions!;
      finalTopicName = widget.topicName ?? "Unknown Topic";
    } else if (widget.data != null) {
      try {
        finalQuestions = (widget.data!['questions'] as List).cast<Question>();
        finalTopicName = widget.data!['topicName'] as String;
      } catch (e) {
        finalQuestions = [];
        finalTopicName = "Error Loading Topic";
      }
    } else {
      finalQuestions = [];
      finalTopicName = "No Data";
    }
    
    // Auto-fill Data
    _topicController.text = finalTopicName;
    _marksController.text = "${finalQuestions.length * 2}";
  }

  // 🧹 CLEAN TEXT FUNCTION (Removes "Exam : ... Year : ...")
  String _cleanQuestionText(String text) {
    // Regex to remove bracket content starting with Exam or Year
    return text.replaceAll(RegExp(r'\s*\(\s*(Exam|Year|SSC|RPSC)\s*:.*?\)', caseSensitive: false), '').trim();
  }

  // 📝 ADMIN INPUT DIALOG
  void _showExamDetailsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text("📝 Paper Details"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInput(_examNameController, "Exam Name"),
                const SizedBox(height: 10),
                _buildInput(_topicController, "Topic Name"),
                const SizedBox(height: 10),
                Row(children: [
                    Expanded(child: _buildInput(_durationController, "Duration")),
                    const SizedBox(width: 10),
                    Expanded(child: _buildInput(_marksController, "Marks")),
                ]),
                const SizedBox(height: 10),
                _buildInput(_watermarkController, "Watermark Text"),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(context);
                _printHtml(isAnswerKey: false); // 🔥 Generate Question Paper
              },
              child: const Text("Print / Save PDF"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInput(TextEditingController ctrl, String label) {
    return TextField(controller: ctrl, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()));
  }

  // 🔥 CORE FUNCTION: HTML TO PDF (With Cover, Layout, Cleaning)
  Future<void> _printHtml({required bool isAnswerKey}) async {
    setState(() => isGenerating = true);

    try {
      final examName = _examNameController.text.toUpperCase();
      final topicName = _topicController.text;
      final time = _durationController.text;
      final marks = _marksController.text;
      final watermarkText = _watermarkController.text.toUpperCase();
      final totalQs = finalQuestions.length;

      // ------------------------------------
      // 1. CSS & STYLES
      // ------------------------------------
      String htmlContent = """
      <!DOCTYPE html>
      <html lang="hi">
      <head>
        <meta charset="UTF-8">
        <link href="https://fonts.googleapis.com/css2?family=Noto+Sans+Devanagari:wght@400;700;800&family=Arimo:wght@400;700&display=swap" rel="stylesheet">
        <style>
          @page { size: A4; margin: 12mm; }
          * { box-sizing: border-box; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
          body { font-family: 'Arimo', sans-serif; background: white; }
          .hindi-font { font-family: 'Noto Sans Devanagari', sans-serif; }
          
          .watermark {
            position: fixed; top: 50%; left: 50%;
            transform: translate(-50%, -50%) rotate(-45deg);
            font-size: 80px; color: rgba(0,0,0,0.04);
            font-weight: bold; z-index: -1000;
            white-space: nowrap; pointer-events: none;
          }

          /* --- COVER PAGE --- */
          .cover-container {
             width: 100%; height: 98vh; position: relative;
             border: 1px solid white; 
             page-break-after: always; /* Force New Page */
          }

          .header-grid { display: flex; justify-content: space-between; align-items: flex-start; border-bottom: 2px solid #000; padding-bottom: 15px; margin-bottom: 10px; }
          .header-left { font-size: 14px; font-weight: bold; width: 30%; }
          .header-center { text-align: center; width: 40%; display: flex; flex-direction: column; align-items: center; }
          .header-right { text-align: right; width: 30%; display: flex; flex-direction: column; align-items: flex-end; }
          
          .exam-name-box { border: 2px solid #000; font-size: 20px; font-weight: 800; padding: 8px 15px; border-radius: 4px; margin-bottom: 5px; font-family: 'Noto Sans Devanagari', sans-serif; background-color: #f9f9f9; text-transform: uppercase; }
          .paper-title { font-size: 18px; font-weight: bold; margin-top: 5px; text-transform: uppercase; }
          
          .warning-box { border: 1px solid #000; padding: 10px; margin: 15px 0; font-size: 11px; text-align: justify; line-height: 1.4; }
          
          .instructions-container { display: flex; gap: 20px; border-top: 2px solid #000; border-bottom: 2px solid #000; margin-top: 10px; }
          .col { flex: 1; padding: 10px 0; }
          .col-left { border-right: 1px solid #000; padding-right: 15px; }
          .col-right { padding-left: 5px; }
          .col-header { text-align: center; font-weight: bold; text-decoration: underline; margin-bottom: 12px; font-size: 14px; }
          .instruction-list { font-size: 10px; line-height: 1.35; padding-left: 18px; text-align: justify; }
          .instruction-list li { margin-bottom: 5px; }

          .footer-warning { font-size: 10px; font-weight: bold; margin-top: 10px; text-align: justify; border-bottom: 1px solid #000; padding-bottom: 8px; }
          .bottom-text { font-size: 10px; margin-top: 8px; font-family: 'Noto Sans Devanagari', sans-serif; }
          .page-footer { display: flex; justify-content: space-between; align-items: center; margin-top: 25px; font-weight: bold; }

          /* --- QUESTIONS PAGE --- */
          .page-header { font-size: 10px; text-align: center; color: grey; margin-bottom: 10px; border-bottom: 1px solid #ccc; padding-top: 20px; }
          .questions-wrapper {
            column-count: 2; column-gap: 30px; column-rule: 1px solid #ddd; width: 100%;
          }
          .question-box { break-inside: avoid; page-break-inside: avoid; margin-bottom: 15px; padding-bottom: 10px; border-bottom: 1px dotted #ccc; }
          .q-text { font-weight: bold; font-size: 13px; margin-bottom: 5px; }
          .options-list { margin-left: 10px; font-size: 12px; }
          .option-item { margin-bottom: 2px; }

          /* --- ANSWER KEY --- */
          .ans-table { width: 100%; border-collapse: collapse; margin-top: 20px; font-size: 14px; }
          .ans-table th { background-color: #333; color: white; padding: 8px; text-align: left; }
          .ans-table td { padding: 6px; border: 1px solid #ddd; }
          .ans-table tr:nth-child(even) { background-color: #f2f2f2; }
        </style>
      </head>
      <body>
        <div class="watermark">$watermarkText</div>
      """;

      // ------------------------------------
      // 2. CONTENT GENERATION
      // ------------------------------------
      
      if (isAnswerKey) {
        // --- ANSWER KEY VIEW ---
        htmlContent += """
        <div style="text-align:center; font-weight:bold; font-size:24px; margin-bottom:10px;">ANSWER KEY</div>
        <div style="text-align:center; font-size:16px; margin-bottom:20px;">$topicName</div>
        <table class='ans-table'><tr><th width="10%">Q.No</th><th>Correct Answer</th></tr>
        """;
        
        List<String> labels = ["(A)", "(B)", "(C)", "(D)", "(E)"];
        for (int i = 0; i < finalQuestions.length; i++) {
          final q = finalQuestions[i];
          String ansText = q.options.isNotEmpty ? q.options[q.correctAnswerIndex] : "-";
          String ansLabel = (q.correctAnswerIndex < 4) ? "<b>${labels[q.correctAnswerIndex]}</b>" : "";
          
          htmlContent += "<tr><td>${i+1}</td><td>$ansLabel $ansText</td></tr>";
        }
        htmlContent += "</table>";

      } else {
        // --- QUESTION PAPER VIEW ---
        
        // 1. Cover Page
        htmlContent += """
        <div class="cover-container">
            <div class="header-grid">
                <div class="header-left hindi-font">
                    पुस्तिका में प्रश्नों की संख्या : $totalQs<br>No. of Questions : $totalQs<br>
                    <div style="margin-top: 15px; font-size: 16px;">Marks : <b>$marks</b></div>
                    <div style="font-size: 16px;">Time : <b>$time</b></div>
                </div>
                <div class="header-center">
                    <div class="exam-name-box">$examName</div>
                    <div class="paper-title">$topicName</div>
                </div>
                <div class="header-right">
                    <div style="height: 40px;"></div>
                    <div class="hindi-font" style="font-size: 10px; margin-top: 25px; text-align: right;">Question Booklet No. & Barcode</div>
                </div>
            </div>
            <div class="warning-box hindi-font">
                प्रश्न पुस्तिका के पेपर की सील खोलने से पूर्व परीक्षार्थी यह सुनिश्चित कर लें कि सभी $totalQs प्रश्न सही मुद्रित हैं।
                <span style="font-family: 'Arimo', sans-serif; display: block; margin-top: 8px;">On opening the paper seal, ensure all questions are properly printed.</span>
            </div>
            <div class="instructions-container">
                <div class="col col-left hindi-font">
                    <div class="col-header">परीक्षार्थियों के लिए निर्देश</div>
                    <ol class="instruction-list">
                        <li>सभी प्रश्नों के अंक समान हैं।</li>
                        <li>प्रत्येक गलत उत्तर के लिए प्रश्न अंक का 1/3 भाग काटा जायेगा।</li>
                        <li>प्रत्येक प्रश्न के पाँच विकल्प (A, B, C, D, E) हैं।</li>
                        <li><b>यदि आप प्रश्न का उत्तर नहीं देना चाहते हैं, तो विकल्प 'E' (अनुतरित प्रश्न) को गहरा करें।</b></li>
                    </ol>
                </div>
                <div class="col col-right">
                    <div class="col-header">INSTRUCTIONS</div>
                    <ol class="instruction-list">
                        <li>All questions carry equal marks.</li>
                        <li>1/3 part of marks will be deducted for each wrong answer.</li>
                        <li>Each question has five options (A, B, C, D, E).</li>
                        <li><b>If you are not attempting a question, darken option 'E' (Unanswered).</b></li>
                    </ol>
                </div>
            </div>
            <div class="footer-warning"><b>Warning:</b> Strict action will be taken for unfair means.</div>
            <div class="bottom-text">OMR की मूल प्रति जमा करें और कार्बन प्रति अपने साथ ले जाएं।</div>
            <div class="page-footer"><div style="font-size: 24px;">Code: 01</div><div>[ QR CODE ]</div></div>
        </div>
        """;

        // 2. Questions List (Starts on Page 2)
        htmlContent += """
        <div class="page-header">$examName - $topicName</div>
        <div class="questions-wrapper">
        """;

        List<String> labels = ["(A)", "(B)", "(C)", "(D)"];

        for (int i = 0; i < finalQuestions.length; i++) {
          final q = finalQuestions[i];

          // 🔥 CLEAN TEXT
          String displayQuestion = _cleanQuestionText(q.questionText);
          
          String optionsHtml = "<div class='options-list'>";
          for(int j=0; j<q.options.length; j++) {
            if(j < 4) {
              optionsHtml += "<div class='option-item'><b>${labels[j]}</b> ${q.options[j]}</div>";
            }
          }
          // 🔥 Add Option E
          optionsHtml += "<div class='option-item'><b>(E)</b> अनुतरित प्रश्न</div>";
          optionsHtml += "</div>";

          htmlContent += """
          <div class="question-box">
            <div class="q-text">Q${i+1}. $displayQuestion</div>
            $optionsHtml
          </div>
          """;
        }
        htmlContent += "</div>";
      }

      htmlContent += "</body></html>";

      // ------------------------------------
      // 3. LAUNCH PRINT DIALOG
      // ------------------------------------
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => await Printing.convertHtml(
          format: format,
          html: htmlContent,
        ),
        name: isAnswerKey ? 'Answer_Key' : 'Question_Paper',
      );

    } catch (e) {
      debugPrint("Print Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => isGenerating = false);
    }
  }

  // 🛠️ CSV GENERATOR
  Future<void> _generateCsv() async {
    setState(() => isGenerating = true);
    try {
      String csvData = "Question,Option A,Option B,Option C,Option D,Correct Answer\n";
      for (var q in finalQuestions) {
        String clean(String s) => s.replaceAll(",", " ").replaceAll("\n", " ").trim();
        String displayQ = _cleanQuestionText(q.questionText); // Clean here too
        
        csvData += "${clean(displayQ)},${q.options.map(clean).join(',')},${clean(q.options[q.correctAnswerIndex])}\n";
      }
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/${finalTopicName.replaceAll(' ', '_')}.csv");
      await file.writeAsString(csvData);
      await Share.shareXFiles([XFile(file.path)], text: 'CSV Export');
    } catch (e) {
      debugPrint("CSV Error: $e");
    } finally {
      setState(() => isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Success"), elevation: 0),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 80),
              const SizedBox(height: 24),
              const Text("Test Generated!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text("Topic: $finalTopicName\nQuestions: ${finalQuestions.length}", textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),

              // ATTEMPT BUTTON
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                  onPressed: () => context.push('/practice-mcq', extra: {'questions': finalQuestions, 'topicName': finalTopicName, 'mode': 'test'}),
                  child: const Text("ATTEMPT TEST NOW"),
                ),
              ),
              const SizedBox(height: 20), const Divider(), const SizedBox(height: 10),
              
              const Text("Downloads", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),

              if (isGenerating) const CircularProgressIndicator() else ...[
                
                // BUTTON 1: Question Paper
                SizedBox(width: double.infinity, child: OutlinedButton.icon(
                  onPressed: () => _showExamDetailsDialog(context), 
                  icon: const Icon(Icons.print, color: Colors.blue),
                  label: const Text("Print Question Paper (PDF)"),
                )),
                const SizedBox(height: 10),
                
                // BUTTON 2: Answer Key
                SizedBox(width: double.infinity, child: OutlinedButton.icon(
                  onPressed: () => _printHtml(isAnswerKey: true), 
                  icon: const Icon(Icons.vpn_key, color: Colors.orange),
                  label: const Text("Print Answer Key (Table PDF)"),
                )),
                const SizedBox(height: 10),

                // BUTTON 3: CSV
                SizedBox(width: double.infinity, child: OutlinedButton.icon(
                  onPressed: _generateCsv,
                  icon: const Icon(Icons.table_chart, color: Colors.green),
                  label: const Text("Download Excel (CSV)"),
                )),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
