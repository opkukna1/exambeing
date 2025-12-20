import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart'; 
import 'package:printing/printing.dart'; // Printing Package
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

  // --- ADMIN INPUTS ---
  final TextEditingController _examNameController = TextEditingController(text: "MOCK TEST SERIES");
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _durationController = TextEditingController(text: "60 Mins");
  final TextEditingController _marksController = TextEditingController();
  final TextEditingController _watermarkController = TextEditingController(text: "EXAMBEING");
  final TextEditingController _instructionsController = TextEditingController(
    text: "1. All questions are compulsory.\n2. No negative marking.\n3. Calculator is prohibited."
  );

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
    
    _topicController.text = finalTopicName;
    _marksController.text = "${finalQuestions.length * 2}";
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
                const SizedBox(height: 10),
                TextField(
                  controller: _instructionsController,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: "Instructions", border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(context);
                _printHtml(isAnswerKey: false); // Print Question Paper
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

  // 🔥 CORE FUNCTION: HTML TO PRINT (With Professional Table)
  Future<void> _printHtml({required bool isAnswerKey}) async {
    setState(() => isGenerating = true);

    try {
      final examName = _examNameController.text.toUpperCase();
      final topicName = _topicController.text;
      final date = "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}";
      final time = _durationController.text;
      final marks = _marksController.text;
      final watermarkText = _watermarkController.text.toUpperCase();
      final instructions = _instructionsController.text.replaceAll('\n', '<br>');

      // ------------------------------------
      // 1. CSS STYLING (Table Design Added)
      // ------------------------------------
      String htmlContent = """
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <style>
          body { font-family: sans-serif; padding: 20px; }
          .header { text-align: center; font-weight: bold; font-size: 24px; margin-bottom: 5px; text-transform: uppercase; }
          .sub-header { text-align: center; font-size: 16px; margin-bottom: 20px; border-bottom: 2px solid black; padding-bottom: 10px; }
          .meta-box { width: 100%; border: 1px solid black; padding: 10px; margin-bottom: 20px; display: flex; justify-content: space-between; }
          .instructions { background-color: #f9f9f9; padding: 10px; border-left: 5px solid #333; margin-bottom: 20px; font-size: 14px; }
          
          .question-box { margin-bottom: 15px; page-break-inside: avoid; }
          .q-text { font-weight: bold; font-size: 16px; margin-bottom: 5px; }
          .options-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 5px; margin-left: 20px; }
          .option { font-size: 14px; }
          
          .watermark {
            position: fixed; top: 50%; left: 50%;
            transform: translate(-50%, -50%) rotate(-45deg);
            font-size: 80px; color: rgba(0,0,0,0.05);
            font-weight: bold; z-index: -1;
            white-space: nowrap; pointer-events: none;
          }

          /* 🔥 BEAUTIFUL TABLE STYLE FOR ANSWER KEY */
          .ans-table { width: 100%; border-collapse: collapse; margin-top: 20px; font-size: 15px; }
          .ans-table th { background-color: #4CAF50; color: white; padding: 10px; border: 1px solid #ddd; text-align: left; }
          .ans-table td { padding: 8px; border: 1px solid #ddd; text-align: left; }
          .ans-table tr:nth-child(even) { background-color: #f2f2f2; }
          .ans-table tr:hover { background-color: #ddd; }
        </style>
      </head>
      <body>

        <div class="watermark">$watermarkText</div>

        <div class="header">${isAnswerKey ? "$topicName - ANSWER KEY" : examName}</div>
        ${!isAnswerKey ? '<div class="sub-header">$topicName</div>' : ''}

        ${!isAnswerKey ? """
        <div class="meta-box">
          <div><b>Date:</b> $date<br><b>Total Qs:</b> ${finalQuestions.length}</div>
          <div style="text-align: right;"><b>Time:</b> $time<br><b>Marks:</b> $marks</div>
        </div>
        <div class="instructions"><b>INSTRUCTIONS:</b><br>$instructions</div>
        """ : ''}

        <hr>
      """;

      // ------------------------------------
      // 2. CONTENT LOOP
      // ------------------------------------
      
      if (isAnswerKey) {
        // ✅ TABLE FORMAT FOR ANSWER KEY
        htmlContent += """
        <h3 style="text-align:center;">CORRECT ANSWERS</h3>
        <table class='ans-table'>
          <tr>
            <th width="15%">Q.No</th>
            <th>Correct Option & Answer</th>
          </tr>
        """;

        List<String> labels = ["(A)", "(B)", "(C)", "(D)"];

        for (int i = 0; i < finalQuestions.length; i++) {
          final q = finalQuestions[i];
          
          // Find correct label (A/B/C/D) and Text
          String ansText = "-";
          String ansLabel = "";
          
          if (q.options.isNotEmpty && q.correctAnswerIndex >= 0 && q.correctAnswerIndex < q.options.length) {
             ansText = q.options[q.correctAnswerIndex];
             // Label A, B, C, D calculate karo
             if (q.correctAnswerIndex < 4) ansLabel = "<b>${labels[q.correctAnswerIndex]}</b> ";
          }

          htmlContent += """
            <tr>
              <td><b>Q.${i+1}</b></td>
              <td>$ansLabel $ansText</td>
            </tr>
          """;
        }
        htmlContent += "</table>";

      } else {
        // --- QUESTION PAPER VIEW (Same as before) ---
        for (int i = 0; i < finalQuestions.length; i++) {
          final q = finalQuestions[i];
          String optionsHtml = "<div class='options-grid'>";
          List<String> labels = ["(A)", "(B)", "(C)", "(D)"];
          for(int j=0; j<q.options.length; j++) {
            if(j < 4) {
              optionsHtml += "<div class='option'><b>${labels[j]}</b> ${q.options[j]}</div>";
            }
          }
          optionsHtml += "</div>";
          htmlContent += """
          <div class="question-box">
            <div class="q-text">Q${i+1}. ${q.questionText}</div>
            $optionsHtml
          </div>
          """;
        }
      }

      htmlContent += "</body></html>";

      // ------------------------------------
      // 3. PRINT
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
        csvData += "${clean(q.questionText)},${q.options.map(clean).join(',')},${clean(q.options[q.correctAnswerIndex])}\n";
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
                
                // BUTTON 2: Answer Key (Table View)
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
