import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart'; 
import 'package:pdf/pdf.dart';
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

  // --- ADMIN INPUT CONTROLLERS ---
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

  // ðŸ§¹ CLEAN TEXT FUNCTION
  String _cleanQuestionText(String text) {
    return text.replaceAll(RegExp(r'\s*\(\s*(Exam|Year|SSC|RPSC|UPSC)\s*:.*?\)', caseSensitive: false), '').trim();
  }

  // ðŸ“ ADMIN INPUT DIALOG
  void _showExamDetailsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text("ðŸ“ Paper Details"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInput(_examNameController, "Exam Name (e.g. RAJASTHAN POLICE)"),
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
                _printHtml(isAnswerKey: false);
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

  // ðŸ”¥ CORE FUNCTION: HTML TO PDF (With Margins Fixed)
  Future<void> _printHtml({required bool isAnswerKey}) async {
    setState(() => isGenerating = true);

    try {
      final examName = _examNameController.text.toUpperCase();
      final topicName = _topicController.text;
      final watermarkText = _watermarkController.text.toUpperCase();
      final totalQs = finalQuestions.length;

      // ------------------------------------
      // 1. CSS STYLES (Margin Fixed Here)
      // ------------------------------------
      String htmlContent = """
      <!DOCTYPE html>
      <html lang="hi">
      <head>
        <meta charset="UTF-8">
        <link href="https://fonts.googleapis.com/css2?family=Noto+Sans+Devanagari:wght@400;700;800&family=Arimo:wght@400;700&display=swap" rel="stylesheet">
        <style>
            /* ðŸ”¥ PAGE MARGINS FIXED HERE */
            @page { 
                size: A4; 
                margin-top: 20mm;    /* Top Margin added */
                margin-bottom: 15mm; 
                margin-left: 15mm; 
                margin-right: 15mm; 
            }
            
            * { box-sizing: border-box; -webkit-print-color-adjust: exact; print-color-adjust: exact; }

            body { 
                background-color: white; 
                font-family: 'Arimo', sans-serif; 
                margin: 0; padding: 0;
            }

            .hindi-font { font-family: 'Noto Sans Devanagari', sans-serif; }
            
            /* WATERMARK */
            .watermark {
                position: fixed; top: 50%; left: 50%;
                transform: translate(-50%, -50%) rotate(-45deg);
                font-size: 80px; color: rgba(0,0,0,0.04);
                font-weight: bold; z-index: -1000;
                white-space: nowrap; pointer-events: none;
            }

            /* --- COVER PAGE --- */
            .a4-page {
                width: 100%; /* Adapt to margins */
                min-height: 90vh;
                position: relative;
                page-break-after: always; 
            }

            .header-grid {
                display: flex; justify-content: space-between; align-items: flex-start;
                border-bottom: 2px solid #000; padding-bottom: 15px; margin-bottom: 10px;
            }
            .header-left { font-size: 14px; font-weight: bold; line-height: 1.5; width: 30%; }
            .header-center { text-align: center; width: 40%; display: flex; flex-direction: column; align-items: center; }
            .header-right { text-align: right; width: 30%; display: flex; flex-direction: column; align-items: flex-end; justify-content: flex-end; }

            .exam-name-box {
                border: 2px solid #000; font-size: 20px; font-weight: 800; padding: 8px 15px;
                border-radius: 4px; margin-bottom: 5px; font-family: 'Noto Sans Devanagari', sans-serif;
                background-color: #f9f9f9; text-transform: uppercase;
            }
            .paper-title { font-size: 18px; font-weight: bold; margin-top: 5px; text-transform: uppercase; }

            .warning-box {
                border: 1px solid #000; padding: 10px; margin: 15px 0;
                font-size: 11.5px; line-height: 1.4; text-align: justify;
            }

            .instructions-container {
                display: flex; gap: 20px; border-top: 2px solid #000; border-bottom: 2px solid #000; margin-top: 10px;
            }
            .col { flex: 1; padding: 10px 0; }
            .col-left { border-right: 1px solid #000; padding-right: 15px; }
            .col-right { padding-left: 5px; }
            .col-header { text-align: center; font-weight: bold; text-decoration: underline; margin-bottom: 12px; font-size: 15px; }
            .instruction-list { font-size: 11px; line-height: 1.35; padding-left: 18px; text-align: justify; }
            .instruction-list li { margin-bottom: 6px; }

            .footer-warning {
                font-size: 10px; font-weight: bold; margin-top: 10px; text-align: justify;
                border-bottom: 1px solid #000; padding-bottom: 8px;
            }
            .bottom-text { font-size: 10px; margin-top: 8px; font-family: 'Noto Sans Devanagari', sans-serif; }
            .page-footer { display: flex; justify-content: space-between; align-items: center; margin-top: 25px; font-weight: bold; }

            /* --- QUESTIONS PAGE CSS --- */
            .questions-page { width: 100%; }
            .page-header { font-size: 10px; text-align: center; color: grey; margin-bottom: 10px; border-bottom: 1px solid #ccc; }
            .questions-wrapper { column-count: 2; column-gap: 30px; column-rule: 1px solid #ddd; width: 100%; }
            .question-box { break-inside: avoid; page-break-inside: avoid; margin-bottom: 15px; padding-bottom: 10px; border-bottom: 1px dotted #ccc; }
            .q-text { font-weight: bold; font-size: 13px; margin-bottom: 5px; }
            .options-list { margin-left: 10px; font-size: 12px; }
            .option-item { margin-bottom: 2px; }
            
            /* ANSWER KEY */
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
        // --- COVER PAGE ---
        htmlContent += """
        <div class="a4-page">
            <div class="header-grid">
                <div class="header-left hindi-font">
                    à¤ªà¥à¤¸à¥à¤¤à¤¿à¤•à¤¾ à¤®à¥‡à¤‚ à¤ªà¥à¤°à¤¶à¥à¤¨à¥‹à¤‚ à¤•à¥€ à¤¸à¤‚à¤–à¥à¤¯à¤¾ : $totalQs<br>
                    No. of Questions in Booklet : $totalQs<br>
                    <div style="margin-top: 15px; font-size: 16px;">Paper Code : <b>01</b></div>
                </div>

                <div class="header-center">
                    <div class="exam-name-box">$examName</div>
                    <div class="paper-title">$topicName</div>
                </div>

                <div class="header-right">
                    <div style="height: 40px;"></div>
                    <div class="hindi-font" style="font-size: 10px; margin-top: 25px; text-align: right;">
                        à¤ªà¥à¤°à¤¶à¥à¤¨ à¤ªà¥à¤¸à¥à¤¤à¤¿à¤•à¤¾ à¤¸à¤‚à¤–à¥à¤¯à¤¾ à¤µ à¤¬à¤¾à¤°à¤•à¥‹à¤¡ /<br>
                        Question Booklet No. & Barcode
                    </div>
                </div>
            </div>

            <div class="warning-box hindi-font">
                à¤ªà¥à¤°à¤¶à¥à¤¨ à¤ªà¥à¤¸à¥à¤¤à¤¿à¤•à¤¾ à¤•à¥‡ à¤ªà¥‡à¤ªà¤° à¤•à¥€ à¤¸à¥€à¤²/à¤ªà¥‰à¤²à¤¿à¤¥à¤¿à¤¨ à¤¬à¥ˆà¤— à¤•à¥‹ à¤–à¥‹à¤²à¤¨à¥‡ à¤ªà¤° à¤ªà¥à¤°à¤¶à¥à¤¨ à¤ªà¤¤à¥à¤° à¤¹à¤² à¤•à¤°à¤¨à¥‡ à¤¸à¥‡ à¤ªà¥‚à¤°à¥à¤µ à¤ªà¤°à¥€à¤•à¥à¤·à¤¾à¤°à¥à¤¥à¥€ à¤¯à¤¹ à¤¸à¥à¤¨à¤¿à¤¶à¥à¤šà¤¿à¤¤ à¤•à¤° à¤²à¥‡à¤‚ à¤•à¤¿ :-
                <ul style="padding-left: 20px; margin: 4px 0;">
                    <li>à¤ªà¥à¤°à¤¶à¥à¤¨ à¤ªà¥à¤¸à¥à¤¤à¤¿à¤•à¤¾ à¤¸à¤‚à¤–à¥à¤¯à¤¾ à¤¤à¤¥à¤¾ à¤“.à¤à¤®.à¤†à¤°. à¤‰à¤¤à¥à¤¤à¤°-à¤ªà¤¤à¥à¤°à¤• à¤ªà¤° à¤…à¤‚à¤•à¤¿à¤¤ à¤¬à¤¾à¤°à¤•à¥‹à¤¡ à¤¸à¤‚à¤–à¥à¤¯à¤¾ à¤¸à¤®à¤¾à¤¨ à¤¹à¥ˆà¥¤</li>
                    <li>à¤¸à¤­à¥€ $totalQs à¤ªà¥à¤°à¤¶à¥à¤¨ à¤¸à¤¹à¥€ à¤®à¥à¤¦à¥à¤°à¤¿à¤¤ à¤¹à¥ˆà¤‚à¥¤</li>
                </ul>
                à¤•à¤¿à¤¸à¥€ à¤­à¥€ à¤ªà¥à¤°à¤•à¤¾à¤° à¤•à¥€ à¤µà¤¿à¤¸à¤‚à¤—à¤¤à¤¿ à¤¯à¤¾ à¤¦à¥‹à¤·à¤ªà¥‚à¤°à¥à¤£ à¤¹à¥‹à¤¨à¥‡ à¤ªà¤° à¤ªà¤°à¥€à¤•à¥à¤·à¤¾à¤°à¥à¤¥à¥€ à¤µà¥€à¤•à¥à¤·à¤• à¤¸à¥‡ à¤¦à¥‚à¤¸à¤°à¥€ à¤ªà¥à¤°à¤¶à¥à¤¨ à¤ªà¥à¤¸à¥à¤¤à¤¿à¤•à¤¾ à¤ªà¥à¤°à¤¾à¤ªà¥à¤¤ à¤•à¤° à¤²à¥‡à¤‚à¥¤ à¤¯à¤¹ à¤¸à¥à¤¨à¤¿à¤¶à¥à¤šà¤¿à¤¤ à¤•à¤°à¤¨à¥‡ à¤•à¥€ à¤œà¤¿à¤®à¥à¤®à¥‡à¤¦à¤¾à¤°à¥€ à¤…à¤­à¥à¤¯à¤°à¥à¤¥à¥€ à¤•à¥€ à¤¹à¥‹à¤—à¥€à¥¤<br>
                <span style="font-family: 'Arimo', sans-serif; display: block; margin-top: 8px;">
                On opening the paper seal/polythene bag of the Question Booklet before attempting the question paper the candidate should ensure that:-
                <ul style="padding-left: 20px; margin: 4px 0;">
                    <li>Question Booklet Number and Barcode Number of OMR Answer Sheet are same.</li>
                    <li>All pages & Questions of Question Booklet and OMR Answer Sheet are properly printed.</li>
                </ul>
                If there is any discrepancy/defect, candidate must obtain another Question Booklet from Invigilator.
                </span>
            </div>

            <div class="instructions-container">
                <div class="col col-left hindi-font">
                    <div class="col-header">à¤ªà¤°à¥€à¤•à¥à¤·à¤¾à¤°à¥à¤¥à¤¿à¤¯à¥‹à¤‚ à¤•à¥‡ à¤²à¤¿à¤ à¤¨à¤¿à¤°à¥à¤¦à¥‡à¤¶</div>
                    <ol class="instruction-list">
                        <li>à¤ªà¥à¤°à¤¤à¥à¤¯à¥‡à¤• à¤ªà¥à¤°à¤¶à¥à¤¨ à¤•à¥‡ à¤²à¤¿à¤¯à¥‡ à¤à¤• à¤µà¤¿à¤•à¤²à¥à¤ª à¤­à¤°à¤¨à¤¾ à¤…à¤¨à¤¿à¤µà¤¾à¤°à¥à¤¯ à¤¹à¥ˆà¥¤</li>
                        <li>à¤¸à¤­à¥€ à¤ªà¥à¤°à¤¶à¥à¤¨à¥‹à¤‚ à¤•à¥‡ à¤…à¤‚à¤• à¤¸à¤®à¤¾à¤¨ à¤¹à¥ˆà¤‚à¥¤</li>
                        <li>à¤à¤• à¤¸à¥‡ à¤…à¤§à¤¿à¤• à¤‰à¤¤à¥à¤¤à¤° à¤¦à¥‡à¤¨à¥‡ à¤•à¥€ à¤¦à¤¶à¤¾ à¤®à¥‡à¤‚ à¤ªà¥à¤°à¤¶à¥à¤¨ à¤•à¥‡ à¤‰à¤¤à¥à¤¤à¤° à¤•à¥‹ à¤—à¤²à¤¤ à¤®à¤¾à¤¨à¤¾ à¤œà¤¾à¤à¤—à¤¾à¥¤</li>
                        <li><b>OMR à¤‰à¤¤à¥à¤¤à¤°-à¤ªà¤¤à¥à¤°à¤•</b> à¤®à¥‡à¤‚ à¤•à¥‡à¤µà¤² <b>à¤¨à¥€à¤²à¥‡ à¤¬à¥‰à¤² à¤ªà¥‰à¤‡à¤‚à¤Ÿ à¤ªà¥‡à¤¨</b> à¤¸à¥‡ à¤µà¤¿à¤µà¤°à¤£ à¤­à¤°à¥‡à¤‚à¥¤</li>
                        <li>à¤•à¥ƒà¤ªà¤¯à¤¾ à¤…à¤ªà¤¨à¤¾ à¤°à¥‹à¤² à¤¨à¤®à¥à¤¬à¤° à¤“.à¤à¤®.à¤†à¤°. à¤‰à¤¤à¥à¤¤à¤°-à¤ªà¤¤à¥à¤°à¤• à¤ªà¤° à¤¸à¤¾à¤µà¤§à¤¾à¤¨à¥€à¤ªà¥‚à¤°à¥à¤µà¤• à¤¸à¤¹à¥€ à¤­à¤°à¥‡à¤‚à¥¤</li>
                        <li>à¤“.à¤à¤®.à¤†à¤°. à¤‰à¤¤à¥à¤¤à¤°-à¤ªà¤¤à¥à¤°à¤• à¤®à¥‡à¤‚ à¤•à¤°à¥‡à¤•à¥à¤¶à¤¨ à¤ªà¥‡à¤¨/à¤µà¥à¤¹à¤¾à¤‡à¤Ÿà¤¨à¤°/à¤¬à¥à¤²à¥‡à¤¡ à¤•à¤¾ à¤‰à¤ªà¤¯à¥‹à¤— à¤¨à¤¿à¤·à¤¿à¤¦à¥à¤§ à¤¹à¥ˆà¥¤</li>
                        <li><b>à¤ªà¥à¤°à¤¤à¥à¤¯à¥‡à¤• à¤—à¤²à¤¤ à¤‰à¤¤à¥à¤¤à¤° à¤•à¥‡ à¤²à¤¿à¤ à¤ªà¥à¤°à¤¶à¥à¤¨ à¤…à¤‚à¤• à¤•à¤¾ 1/3 à¤­à¤¾à¤— à¤•à¤¾à¤Ÿà¤¾ à¤œà¤¾à¤¯à¥‡à¤—à¤¾à¥¤</b></li>
                        <li>à¤ªà¥à¤°à¤¤à¥à¤¯à¥‡à¤• à¤ªà¥à¤°à¤¶à¥à¤¨ à¤•à¥‡ à¤ªà¤¾à¤à¤š à¤µà¤¿à¤•à¤²à¥à¤ª à¤¦à¤¿à¤ à¤—à¤¯à¥‡ à¤¹à¥ˆà¤‚ (A, B, C, D, E)à¥¤</li>
                        <li><b>à¤¯à¤¦à¤¿ à¤†à¤ª à¤ªà¥à¤°à¤¶à¥à¤¨ à¤•à¤¾ à¤‰à¤¤à¥à¤¤à¤° à¤¨à¤¹à¥€à¤‚ à¤¦à¥‡à¤¨à¤¾ à¤šà¤¾à¤¹à¤¤à¥‡ à¤¹à¥ˆà¤‚, à¤¤à¥‹ à¤‰à¤¤à¥à¤¤à¤°-à¤ªà¤¤à¥à¤°à¤• à¤®à¥‡à¤‚ à¤ªà¤¾à¤‚à¤šà¤µà¥‡à¤‚ (E) à¤µà¤¿à¤•à¤²à¥à¤ª à¤•à¥‹ à¤—à¤¹à¤°à¤¾ à¤•à¤°à¥‡à¤‚à¥¤</b> à¤¯à¤¦à¤¿ à¤ªà¤¾à¤‚à¤š à¤®à¥‡à¤‚ à¤¸à¥‡ à¤•à¥‹à¤ˆ à¤­à¥€ à¤—à¥‹à¤²à¤¾ à¤—à¤¹à¤°à¤¾ à¤¨à¤¹à¥€à¤‚ à¤•à¤¿à¤¯à¤¾ à¤œà¤¾à¤¤à¤¾ à¤¹à¥ˆ, à¤¤à¥‹ <b>1/3 à¤­à¤¾à¤— à¤•à¤¾à¤Ÿà¤¾ à¤œà¤¾à¤¯à¥‡à¤—à¤¾à¥¤</b></li>
                        <li>à¤®à¥‹à¤¬à¤¾à¤‡à¤² à¤«à¥‹à¤¨ à¤…à¤¥à¤µà¤¾ à¤‡à¤²à¥‡à¤•à¥à¤Ÿà¥à¤°à¥‰à¤¨à¤¿à¤• à¤¯à¤‚à¤¤à¥à¤° à¤•à¤¾ à¤ªà¤°à¥€à¤•à¥à¤·à¤¾ à¤¹à¥‰à¤² à¤®à¥‡à¤‚ à¤ªà¥à¤°à¤¯à¥‹à¤— à¤ªà¥‚à¤°à¥à¤£à¤¤à¤¯à¤¾ à¤µà¤°à¥à¤œà¤¿à¤¤ à¤¹à¥ˆà¥¤</li>
                    </ol>
                </div>

                <div class="col col-right">
                    <div class="col-header">INSTRUCTIONS FOR CANDIDATES</div>
                    <ol class="instruction-list">
                        <li>It is mandatory to fill one option for each question.</li>
                        <li>All questions carry equal marks.</li>
                        <li>If more than one answer is marked, it would be treated as wrong answer.</li>
                        <li>Fill in the particulars carefully with <b>BLUE BALL POINT PEN</b> only.</li>
                        <li>Please correctly fill your Roll Number in OMR Answer Sheet.</li>
                        <li>Use of Correction Pen/Whitener in the OMR Answer Sheet is strictly forbidden.</li>
                        <li><b>1/3 part of the mark(s) of each question will be deducted for each wrong answer.</b></li>
                        <li>Each question has five options marked as A, B, C, D, E.</li>
                        <li><b>If you are not attempting a question, then you have to darken the circle 'E'. If none of the five circles is darkened, 1/3 part of the marks shall be deducted.</b></li>
                        <li>Mobile Phone or any other electronic gadget is strictly prohibited.</li>
                    </ol>
                </div>
            </div>

            <div class="footer-warning">
                <b>Warning:</b> If a candidate is found copying, F.I.R. would be lodged against him/her under <b>Rajasthan Public Examination Act, 2022</b>.
            </div>

            <div class="bottom-text">
                à¤‰à¤¤à¥à¤¤à¤°-à¤ªà¤¤à¥à¤°à¤• à¤®à¥‡à¤‚ à¤¦à¥‹ à¤ªà¥à¤°à¤¤à¤¿à¤¯à¤¾à¤‚ à¤¹à¥ˆà¤‚ - à¤®à¥‚à¤² à¤ªà¥à¤°à¤¤à¤¿ à¤”à¤° à¤•à¤¾à¤°à¥à¤¬à¤¨ à¤ªà¥à¤°à¤¤à¤¿à¥¤ à¤ªà¤°à¥€à¤•à¥à¤·à¤¾ à¤¸à¤®à¤¾à¤ªà¥à¤¤à¤¿ à¤ªà¤° à¤ªà¤°à¥€à¤•à¥à¤·à¤¾ à¤•à¤•à¥à¤· à¤›à¥‹à¤¡à¤¼à¤¨à¥‡ à¤¸à¥‡ à¤ªà¥‚à¤°à¥à¤µ à¤ªà¤°à¥€à¤•à¥à¤·à¤¾à¤°à¥à¤¥à¥€ à¤‰à¤¤à¥à¤¤à¤°-à¤ªà¤¤à¥à¤°à¤• à¤•à¥€ à¤¦à¥‹à¤¨à¥‹à¤‚ à¤ªà¥à¤°à¤¤à¤¿à¤¯à¤¾à¤‚ à¤µà¥€à¤•à¥à¤·à¤• à¤•à¥‹ à¤¸à¥Œà¤‚à¤ªà¥‡à¤‚à¤—à¥‡à¥¤
            </div>

            <div class="page-footer">
                <div style="font-size: 24px;">00 - ðŸŒ‘</div>
                <div>[ QR CODE ]</div>
            </div>
        </div>
        """;

        // --- QUESTIONS LIST ---
        htmlContent += """
        <div class="questions-page">
        <div class="page-header">$examName - $topicName</div>
        <div class="questions-wrapper">
        """;

        List<String> labels = ["(A)", "(B)", "(C)", "(D)"];

        for (int i = 0; i < finalQuestions.length; i++) {
          final q = finalQuestions[i];
          String displayQuestion = _cleanQuestionText(q.questionText);
          
          String optionsHtml = "<div class='options-list'>";
          for(int j=0; j<q.options.length; j++) {
            if(j < 4) {
              optionsHtml += "<div class='option-item'><b>${labels[j]}</b> ${q.options[j]}</div>";
            }
          }
          optionsHtml += "<div class='option-item'><b>(E)</b> à¤…à¤¨à¥à¤¤à¤°à¤¿à¤¤ à¤ªà¥à¤°à¤¶à¥à¤¨</div>";
          optionsHtml += "</div>";

          htmlContent += """
          <div class="question-box">
            <div class="q-text">Q${i+1}. $displayQuestion</div>
            $optionsHtml
          </div>
          """;
        }
        htmlContent += "</div></div>";
      }

      htmlContent += "</body></html>";

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

  // ðŸ› ï¸ CSV GENERATOR
  Future<void> _generateCsv() async {
    setState(() => isGenerating = true);
    try {
      String csvData = "Question,Option A,Option B,Option C,Option D,Correct Answer\n";
      for (var q in finalQuestions) {
        String clean(String s) => s.replaceAll(",", " ").replaceAll("\n", " ").trim();
        String displayQ = _cleanQuestionText(q.questionText);
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
