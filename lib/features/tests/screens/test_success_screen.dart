import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart'; // PDF Fonts & Layout
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

  // Controllers for Admin Input
  final TextEditingController _examNameController = TextEditingController(text: "MOCK TEST SERIES - 2025");
  final TextEditingController _durationController = TextEditingController(text: "60 Mins");
  final TextEditingController _marksController = TextEditingController();

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
    // Default Marks logic (e.g., 2 marks per question)
    _marksController.text = "${finalQuestions.length * 2}";
  }

  @override
  void dispose() {
    _examNameController.dispose();
    _durationController.dispose();
    _marksController.dispose();
    super.dispose();
  }

  // 🔒 1. CHECK PREMIUM & HANDLER
  Future<void> _checkPremiumAndAction(BuildContext context, {required String actionType}) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please login first!")));
      return;
    }

    // Show Loading
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!mounted) return;
      Navigator.pop(context); // Hide Loading

      final data = userDoc.data();
      final String paidStatus = data != null && data.containsKey('paid_for_gold') ? data['paid_for_gold'] : 'no';

      if (paidStatus == 'yes') {
        if (actionType == 'csv') {
          await _generateAndShareCsv(context);
        } else if (actionType == 'pdf_paper') {
          // Show Input Dialog first for Exam Details
          _showExamDetailsDialog(context);
        } else if (actionType == 'pdf_key') {
          await _generateAnswerKeyPdf(context);
        }
      } else {
        _showPremiumSnackBar(context);
      }
    } catch (e) {
      if (mounted) {
        if (Navigator.canPop(context)) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  void _showPremiumSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Premium feature for educators.\nContact: 8005576670"),
        backgroundColor: Colors.black87,
        action: SnackBarAction(
          label: 'COPY',
          textColor: Colors.amber,
          onPressed: () => Clipboard.setData(const ClipboardData(text: "8005576670")),
        ),
      ),
    );
  }

  // 📝 2. ADMIN INPUT DIALOG
  void _showExamDetailsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("📝 Exam Details"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: _examNameController, decoration: const InputDecoration(labelText: "Exam Name", hintText: "e.g. UPSC Prelims Mock")),
                TextField(controller: _durationController, decoration: const InputDecoration(labelText: "Duration", hintText: "e.g. 120 Mins")),
                TextField(controller: _marksController, decoration: const InputDecoration(labelText: "Total Marks", hintText: "e.g. 200")),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _generateQuestionPaperPdf(context); // Call PDF Generator
              },
              child: const Text("Generate PDF"),
            ),
          ],
        );
      },
    );
  }

  // 📄 3. PROFESSIONAL PDF GENERATOR (Question Paper)
  Future<void> _generateQuestionPaperPdf(BuildContext context) async {
    try {
      final pdf = pw.Document();
      final font = await PdfGoogleFonts.poppinsRegular();
      final boldFont = await PdfGoogleFonts.poppinsBold();

      // Get Values from Controllers
      final String examName = _examNameController.text.toUpperCase();
      final String duration = _durationController.text;
      final String marks = _marksController.text;
      final String date = "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}";

      // Styles
      final headerStyle = pw.TextStyle(font: boldFont, fontSize: 18);
      final questionStyle = pw.TextStyle(font: boldFont, fontSize: 10);
      final optionStyle = pw.TextStyle(font: font, fontSize: 9);

      // Watermark Helper
      pw.Widget buildWatermark() {
        return pw.Center(
          child: pw.Transform.rotate(
            angle: -0.5,
            child: pw.Opacity(
              opacity: 0.1,
              child: pw.Text("EXAMBEING", style: pw.TextStyle(font: boldFont, fontSize: 60, color: PdfColors.grey)),
            ),
          ),
        );
      }

      // --- PAGE 1: COVER PAGE ---
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) {
            return pw.Stack(
              children: [
                buildWatermark(),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Center(child: pw.Text(examName, style: headerStyle, textAlign: pw.TextAlign.center)),
                    pw.SizedBox(height: 5),
                    pw.Center(child: pw.Text("TOPIC: ${finalTopicName.toUpperCase()}", style: pw.TextStyle(font: font, fontSize: 12))),
                    pw.Divider(thickness: 2),
                    pw.SizedBox(height: 10),
                    
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                          pw.Text("Date: $date", style: optionStyle),
                          pw.Text("Questions: ${finalQuestions.length}", style: optionStyle),
                        ]),
                        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                          pw.Text("Duration: $duration", style: optionStyle),
                          pw.Text("Max Marks: $marks", style: optionStyle),
                        ]),
                      ],
                    ),
                    pw.SizedBox(height: 20),
                    pw.Text("INSTRUCTIONS:", style: pw.TextStyle(font: boldFont, decoration: pw.TextDecoration.underline)),
                    pw.SizedBox(height: 5),
                    pw.Text("1. All questions are compulsory.\n2. No negative marking unless specified.\n3. Use of calculators is prohibited.\n4. Keep your mobile phones switched off.", style: pw.TextStyle(font: font, fontSize: 10, lineSpacing: 1.5)),
                    pw.Spacer(),
                    pw.Center(child: pw.Text("~ Best of Luck ~", style: pw.TextStyle(font: font, fontStyle: pw.FontStyle.italic))),
                  ],
                ),
              ],
            );
          },
        ),
      );

      // --- PAGE 2+: QUESTIONS (Fixed Split Column Logic) ---
      // We calculate width for 2 columns: (PageWidth - LeftMargin - RightMargin - Spacing) / 2
      final double pageContentWidth = PdfPageFormat.a4.width - 40; // 20 margin each side
      final double columnWidth = (pageContentWidth - 15) / 2; // 15 spacing

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          // columns: 2, // ❌ REMOVED THIS CAUSING ERROR
          build: (context) {
            return [
              pw.Wrap( // ✅ USED WRAP TO SIMULATE 2 COLUMNS
                spacing: 15, // Gap between columns
                runSpacing: 15, // Gap between rows
                children: List.generate(finalQuestions.length, (index) {
                  final q = finalQuestions[index];
                  return pw.Container(
                    width: columnWidth, // Force width to half page
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("Q${index + 1}. ${q.questionText}", style: questionStyle),
                        pw.SizedBox(height: 4),
                        if (q.options.isNotEmpty) pw.Text("(A) ${q.options[0]}", style: optionStyle),
                        if (q.options.length > 1) pw.Text("(B) ${q.options[1]}", style: optionStyle),
                        if (q.options.length > 2) pw.Text("(C) ${q.options[2]}", style: optionStyle),
                        if (q.options.length > 3) pw.Text("(D) ${q.options[3]}", style: optionStyle),
                      ],
                    ),
                  );
                }),
              )
            ];
          },
        ),
      );

      // Save & Share
      final output = await pdf.save();
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/ExamBeing_Paper_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(output);
      await Share.shareXFiles([XFile(file.path)], text: 'Here is your Exam Paper PDF');

    } catch (e) {
      debugPrint(e.toString());
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("PDF Error: $e")));
    }
  }

  // 📄 4. ANSWER KEY PDF
  Future<void> _generateAnswerKeyPdf(BuildContext context) async {
    try {
      final pdf = pw.Document();
      final font = await PdfGoogleFonts.poppinsRegular();
      final boldFont = await PdfGoogleFonts.poppinsBold();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) {
            return [
              pw.Header(level: 0, child: pw.Text("ANSWER KEY - $finalTopicName", style: pw.TextStyle(font: boldFont, fontSize: 16))),
              pw.Table.fromTextArray(
                headers: ['Q', 'Correct Answer', 'Explanation'],
                data: List<List<dynamic>>.generate(finalQuestions.length, (index) {
                  final q = finalQuestions[index];
                  String ans = "";
                  if (q.options.isNotEmpty && q.correctAnswerIndex < q.options.length) {
                    ans = "(${String.fromCharCode(65 + q.correctAnswerIndex)}) ${q.options[q.correctAnswerIndex]}";
                  }
                  return ['${index + 1}', ans, q.explanation];
                }),
                headerStyle: pw.TextStyle(font: boldFont, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.deepPurple),
                cellStyle: pw.TextStyle(font: font, fontSize: 9),
                cellAlignments: {0: pw.Alignment.center, 1: pw.Alignment.centerLeft, 2: pw.Alignment.centerLeft},
              ),
            ];
          },
        ),
      );

      final output = await pdf.save();
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/ExamBeing_Key_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(output);
      await Share.shareXFiles([XFile(file.path)], text: 'Here is your Answer Key PDF');

    } catch (e) {
      debugPrint(e.toString());
    }
  }

  // 📄 5. CSV GENERATOR
  Future<void> _generateAndShareCsv(BuildContext context) async {
    try {
      List<List<dynamic>> rows = [];
      rows.add(["Question", "Option A", "Option B", "Option C", "Option D", "Correct Answer", "Explanation"]);

      for (var q in finalQuestions) {
        String correctAnswerText = "";
        if (q.options.isNotEmpty && q.correctAnswerIndex >= 0 && q.correctAnswerIndex < q.options.length) {
           correctAnswerText = q.options[q.correctAnswerIndex];
        }
        rows.add([q.questionText, q.options.length > 0 ? q.options[0] : "", q.options.length > 1 ? q.options[1] : "", q.options.length > 2 ? q.options[2] : "", q.options.length > 3 ? q.options[3] : "", correctAnswerText, q.explanation]);
      }

      String csvData = const ListToCsvConverter().convert(rows);
      final directory = await getTemporaryDirectory();
      final File file = File('${directory.path}/ExamBeing_Data.csv');
      await file.writeAsString(csvData);
      await Share.shareXFiles([XFile(file.path)], text: 'Test CSV');
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("CSV Error: $e")));
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

              // Attempt Button
              SizedBox(
                width: double.infinity, height: 55,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  onPressed: () => context.push('/practice-mcq', extra: {'questions': finalQuestions, 'topicName': finalTopicName, 'mode': 'test'}),
                  icon: const Icon(Icons.play_arrow_rounded, size: 28),
                  label: const Text("ATTEMPT TEST NOW", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              
              const SizedBox(height: 30), const Divider(thickness: 1.5), const SizedBox(height: 15),
              const Text("Educator Tools (Premium)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      onPressed: () => _checkPremiumAndAction(context, actionType: 'pdf_paper'),
                      icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                      label: const Text("PDF Paper"),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      onPressed: () => _checkPremiumAndAction(context, actionType: 'pdf_key'),
                      icon: const Icon(Icons.vpn_key, color: Colors.green),
                      label: const Text("Answer Key"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: () => _checkPremiumAndAction(context, actionType: 'csv'),
                  icon: const Icon(Icons.table_chart, color: Colors.teal),
                  label: const Text("Export as CSV (Excel)"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
