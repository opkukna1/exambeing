import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  // --- ADMIN INPUTS ---
  final TextEditingController _examNameController = TextEditingController(text: "MOCK TEST SERIES");
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _durationController = TextEditingController(text: "60 Mins");
  final TextEditingController _marksController = TextEditingController();
  final TextEditingController _watermarkController = TextEditingController(text: "EXAMBEING");
  final TextEditingController _instructionsController = TextEditingController(
    text: "1. All questions are compulsory.\n2. No negative marking.\n3. Calculator is prohibited.\n4. Read questions carefully."
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

  // 🔥 CORE FUNCTION: HTML TO PRINT (SPLIT COLUMNS & COVER PAGE)
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
      // 1. CSS STYLING (Two Columns + Margins)
      // ------------------------------------
      String htmlContent = """
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <style>
          /* PAGE MARGINS & SETTINGS */
          @page { size: A4; margin: 15mm; } 
          body { font-family: sans-serif; -webkit-print-color-adjust: exact; }

          /* WATERMARK (Fixed on every page) */
          .watermark {
            position: fixed; top: 50%; left: 50%;
            transform: translate(-50%, -50%) rotate(-45deg);
            font-size: 80px; color: rgba(0,0,0,0.05);
            font-weight: bold; z-index: -1000;
            white-space: nowrap; pointer-events: none;
          }

          /* COVER PAGE STYLES */
          .cover-page {
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
            height: 90vh; /* Takes full first page */
            text-align: center;
            page-break-after: always; /* 🔥 Forces New Page */
            break-after: page;
          }
          
          .exam-title { font-size: 32px; font-weight: bold; margin-bottom: 10px; text-transform: uppercase; border-bottom: 3px solid #333; padding-bottom: 10px; display: inline-block;}
          .topic-title { font-size: 22px; margin-bottom: 40px; color: #555; }
          
          .meta-table { width: 100%; border: 2px solid black; margin-bottom: 40px; font-size: 18px; }
          .meta-table td { padding: 15px; border: 1px solid black; }

          .instructions-box { text-align: left; width: 100%; background: #f4f4f4; padding: 20px; border: 1px dashed #333; }
          
          /* TWO COLUMN LAYOUT FOR QUESTIONS */
          .questions-wrapper {
            column-count: 2; /* 🔥 Split into 2 columns */
            column-gap: 30px;
            column-rule: 1px solid #ddd; /* Line between columns */
            width: 100%;
          }

          .question-box {
            break-inside: avoid; /* Don't split a single question */
            page-break-inside: avoid;
            margin-bottom: 15px;
            padding-bottom: 10px;
            border-bottom: 1px dotted #ccc;
          }

          .q-text { font-weight: bold; font-size: 14px; margin-bottom: 5px; }
          .options-list { margin-left: 15px; font-size: 13px; }
          .option-item { margin-bottom: 2px; }

          /* ANSWER KEY TABLE */
          .ans-table { width: 100%; border-collapse: collapse; margin-top: 20px; font-size: 14px; }
          .ans-table th { background-color: #333; color: white; padding: 8px; text-align: left; }
          .ans-table td { padding: 6px; border: 1px solid #ddd; }
          .ans-table tr:nth-child(even) { background-color: #f2f2f2; }

          /* Header on pages after cover (Optional) */
          .page-header { font-size: 10px; text-align: center; color: grey; margin-bottom: 10px; border-bottom: 1px solid #ccc; }
        </style>
      </head>
      <body>

        <div class="watermark">$watermarkText</div>

      """;

      // ------------------------------------
      // 2. CONTENT LOGIC
      // ------------------------------------
      
      if (isAnswerKey) {
        // --- ANSWER KEY (No Cover Page needed usually, but lets keep header) ---
        htmlContent += """
        <div style="text-align:center; font-weight:bold; font-size:24px; margin-bottom:10px;">ANSWER KEY</div>
        <div style="text-align:center; font-size:16px; margin-bottom:20px;">$topicName</div>
        
        <table class='ans-table'>
          <tr><th width="10%">Q.No</th><th>Correct Answer</th></tr>
        """;
        
        List<String> labels = ["(A)", "(B)", "(C)", "(D)"];
        for (int i = 0; i < finalQuestions.length; i++) {
          final q = finalQuestions[i];
          String ansText = q.options.isNotEmpty ? q.options[q.correctAnswerIndex] : "-";
          String ansLabel = (q.correctAnswerIndex < 4) ? "<b>${labels[q.correctAnswerIndex]}</b>" : "";
          
          htmlContent += "<tr><td>${i+1}</td><td>$ansLabel $ansText</td></tr>";
        }
        htmlContent += "</table>";

      } else {
        // --- QUESTION PAPER (Cover Page + 2 Columns) ---
        
        // 1. COVER PAGE
        htmlContent += """
        <div class="cover-page">
          <div class="exam-title">$examName</div>
          <div class="topic-title">$topicName</div>

          <table class="meta-table">
            <tr>
              <td><b>Date:</b><br>$date</td>
              <td><b>Time:</b><br>$time</td>
            </tr>
            <tr>
              <td><b>Total Questions:</b><br>${finalQuestions.length}</td>
              <td><b>Max Marks:</b><br>$marks</td>
            </tr>
          </table>

          <div class="instructions-box">
            <h3>INSTRUCTIONS / निर्देश:</h3>
            <p>$instructions</p>
          </div>
          
          <br><br>
          <div style="font-size:12px; color:grey;">- Paper starts on next page -</div>
        </div>
        """;

        // 2. QUESTIONS PAGE (Split Columns)
        htmlContent += """
        <div class="page-header">$examName - $topicName</div>
        <div class="questions-wrapper">
        """;

        List<String> labels = ["(A)", "(B)", "(C)", "(D)"];
        for (int i = 0; i < finalQuestions.length; i++) {
          final q = finalQuestions[i];
          
          String optionsHtml = "<div class='options-list'>";
          for(int j=0; j<q.options.length; j++) {
            if(j < 4) {
              optionsHtml += "<div class='option-item'><b>${labels[j]}</b> ${q.options[j]}</div>";
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

        htmlContent += "</div>"; // Close wrapper
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
