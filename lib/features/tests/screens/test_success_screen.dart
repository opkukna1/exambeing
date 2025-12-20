import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // RootBundle
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart'; // ✅ Share use kar rahe hain
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw; // PDF Widgets
// ❌ import 'package:open_file/open_file.dart'; // REMOVED THIS LINE
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
    
    // Auto-fill Data
    _topicController.text = finalTopicName;
    _marksController.text = "${finalQuestions.length * 2}";
  }

  // 🔒 CHECK PREMIUM LOGIC
  Future<void> _checkPremiumAndAction(BuildContext context, int actionType) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please login first!")));
      return;
    }

    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!mounted) return;
      Navigator.pop(context); 

      final data = userDoc.data();
      final String paidStatus = data != null && data.containsKey('paid_for_gold') ? data['paid_for_gold'] : 'no';

      if (paidStatus == 'yes') {
        if (actionType == 1) {
          _showExamDetailsDialog(context); 
        } else {
          _generatePdf(isAnswerKey: true); 
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("🔒 Premium Feature! Contact Admin to unlock.")));
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  // 📝 ADMIN INPUT DIALOG
  void _showExamDetailsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text("📝 PDF Details", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInput(_examNameController, "Exam Name"),
                const SizedBox(height: 10),
                _buildInput(_topicController, "Topic Name"),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildInput(_durationController, "Duration")),
                    const SizedBox(width: 10),
                    Expanded(child: _buildInput(_marksController, "Marks")),
                  ],
                ),
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
                _generatePdf(isAnswerKey: false); 
              },
              child: const Text("Generate PDF"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInput(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    );
  }

  // 🔥 CORE PDF GENERATOR
  Future<void> _generatePdf({required bool isAnswerKey}) async {
    setState(() => isGenerating = true);

    try {
      final pdf = pw.Document();

      // Load Hindi Font
      final fontData = await rootBundle.load("assets/fonts/NotoSans.ttf");
      final ttf = pw.Font.ttf(fontData);

      final theme = pw.ThemeData.withFont(
        base: ttf,
        bold: ttf, 
      );

      final examName = _examNameController.text.toUpperCase();
      final topicName = _topicController.text;
      final time = _durationController.text;
      final marks = _marksController.text;
      final watermarkText = _watermarkController.text.toUpperCase();
      final instructions = _instructionsController.text.split('\n');
      final date = "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}";

      final headerStyle = pw.TextStyle(font: ttf, fontSize: 20, fontWeight: pw.FontWeight.bold);
      final subHeaderStyle = pw.TextStyle(font: ttf, fontSize: 12);
      final textStyle = pw.TextStyle(font: ttf, fontSize: 10);
      
      pw.Widget buildWatermark() {
        return pw.Center(
          child: pw.Transform.rotate(
            angle: -0.5,
            child: pw.Opacity(
              opacity: 0.08,
              child: pw.Text(watermarkText, style: pw.TextStyle(font: ttf, fontSize: 70, color: PdfColors.grey)),
            ),
          ),
        );
      }

      if (isAnswerKey) {
        // ANSWER KEY LAYOUT
        pdf.addPage(
          pw.MultiPage(
            theme: theme,
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            build: (context) {
              return [
                pw.Header(
                  level: 0,
                  child: pw.Center(
                    child: pw.Text("$topicName - Answer Key", style: headerStyle),
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Wrap(
                  spacing: 20,
                  runSpacing: 10,
                  children: List.generate(finalQuestions.length, (index) {
                    final q = finalQuestions[index];
                    final correctAns = q.options[q.correctAnswerIndex];
                    return pw.Container(
                      width: 150,
                      padding: const pw.EdgeInsets.all(5),
                      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
                      child: pw.Row(children: [
                        pw.Text("${index + 1}. ", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                        pw.Expanded(child: pw.Text(correctAns, style: textStyle)),
                      ])
                    );
                  })
                )
              ];
            },
          )
        );
      } else {
        // QUESTION PAPER LAYOUT
        pdf.addPage(
          pw.Page(
            theme: theme,
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(30),
            build: (context) {
              return pw.Stack(
                children: [
                  buildWatermark(),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Center(child: pw.Text(examName, style: headerStyle, textAlign: pw.TextAlign.center)),
                      pw.SizedBox(height: 5),
                      pw.Center(child: pw.Text(topicName, style: subHeaderStyle)),
                      pw.Divider(thickness: 1.5),
                      pw.SizedBox(height: 15),
                      
                      pw.Container(
                        padding: const pw.EdgeInsets.all(10),
                        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black)),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                              pw.Text("Date: $date", style: textStyle),
                              pw.Text("Total Qs: ${finalQuestions.length}", style: textStyle),
                            ]),
                            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                              pw.Text("Time: $time", style: textStyle),
                              pw.Text("Marks: $marks", style: textStyle),
                            ]),
                          ],
                        ),
                      ),
                      
                      pw.SizedBox(height: 30),
                      pw.Text("INSTRUCTIONS / निर्देश:", style: pw.TextStyle(font: ttf, fontSize: 14, decoration: pw.TextDecoration.underline, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 10),
                      
                      ...instructions.map((inst) => pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text("• ", style: textStyle), 
                            pw.Expanded(child: pw.Text(inst, style: textStyle)),
                          ],
                        ),
                      )),
                      pw.Spacer(),
                      pw.Center(child: pw.Text("--- Paper Starts on Next Page ---", style: pw.TextStyle(font: ttf, fontStyle: pw.FontStyle.italic))),
                    ],
                  ),
                ],
              );
            },
          ),
        );

        final double pageWidth = PdfPageFormat.a4.width - 60; 
        final double colWidth = (pageWidth - 20) / 2;

        pdf.addPage(
          pw.MultiPage(
            theme: theme,
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(30),
            build: (context) {
              return [
                pw.Wrap(
                  spacing: 20, 
                  runSpacing: 15, 
                  children: List.generate(finalQuestions.length, (index) {
                    final q = finalQuestions[index];
                    return pw.Container(
                      width: colWidth,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("Q${index + 1}. ${q.questionText}", style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold, fontSize: 11)),
                          pw.SizedBox(height: 3),
                          if(q.options.isNotEmpty) pw.Text("(A) ${q.options[0]}", style: textStyle),
                          if(q.options.length > 1) pw.Text("(B) ${q.options[1]}", style: textStyle),
                          if(q.options.length > 2) pw.Text("(C) ${q.options[2]}", style: textStyle),
                          if(q.options.length > 3) pw.Text("(D) ${q.options[3]}", style: textStyle),
                        ],
                      ),
                    );
                  }),
                )
              ];
            },
            pageTheme: pw.PageTheme(
              pageFormat: PdfPageFormat.a4,
              margin: const pw.EdgeInsets.all(30),
              buildBackground: (context) => buildWatermark(),
              theme: theme,
            ),
          ),
        );
      }

      final output = await getTemporaryDirectory();
      final String fileName = isAnswerKey ? "${topicName}_Key.pdf" : "${topicName}_Exam.pdf";
      final file = File('${output.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles([XFile(file.path)], text: isAnswerKey ? 'Answer Key' : 'Exam Paper');

    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("PDF Error: $e")));
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
        
        String qText = clean(q.questionText);
        String optA = q.options.isNotEmpty ? clean(q.options[0]) : "";
        String optB = q.options.length > 1 ? clean(q.options[1]) : "";
        String optC = q.options.length > 2 ? clean(q.options[2]) : "";
        String optD = q.options.length > 3 ? clean(q.options[3]) : "";
        String correct = clean(q.options[q.correctAnswerIndex]);

        csvData += "$qText,$optA,$optB,$optC,$optD,$correct\n";
      }

      final output = await getTemporaryDirectory();
      final file = File("${output.path}/${finalTopicName.replaceAll(' ', '_')}.csv");
      await file.writeAsString(csvData);
      
      await Share.shareXFiles([XFile(file.path)], text: 'Exported CSV');

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
              const Text("Test Generated Successfully!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text("Topic: $finalTopicName\nQuestions: ${finalQuestions.length}", style: const TextStyle(fontSize: 16, color: Colors.grey), textAlign: TextAlign.center),
              const SizedBox(height: 40),

              // 1. ATTEMPT TEST BUTTON
              SizedBox(
                width: double.infinity, height: 55,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  onPressed: () => context.push('/practice-mcq', extra: {'questions': finalQuestions, 'topicName': finalTopicName, 'mode': 'test'}),
                  icon: const Icon(Icons.play_arrow_rounded, size: 28),
                  label: const Text("ATTEMPT TEST NOW", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              
              const SizedBox(height: 20),
              const Divider(thickness: 1.5),
              const SizedBox(height: 10),
              const Text("Educator Tools (Premium)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 15),

              if (isGenerating) 
                const CircularProgressIndicator()
              else ...[
                // 2. DOWNLOAD QUESTION PAPER
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () => _checkPremiumAndAction(context, 1),
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                    label: const Text("Download Question Paper (PDF)"),
                  ),
                ),
                const SizedBox(height: 15),

                // 3. DOWNLOAD ANSWER KEY
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () => _checkPremiumAndAction(context, 2),
                    icon: const Icon(Icons.vpn_key, color: Colors.orange),
                    label: const Text("Download Answer Key (PDF)"),
                  ),
                ),
                const SizedBox(height: 15),

                // 4. DOWNLOAD CSV
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: _generateCsv,
                    icon: const Icon(Icons.table_chart, color: Colors.green),
                    label: const Text("Download CSV (Excel)"),
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
