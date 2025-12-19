import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart'; // Font load karne ke liye zaroori hai
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

  // 🔒 CHECK PREMIUM
  Future<void> _checkPremiumAndAction(BuildContext context) async {
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
        _showExamDetailsDialog(context); // Open Input Dialog
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Premium Feature! Contact Admin.")));
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  // 📝 ADMIN INPUT DIALOG (Black Text Fix)
  void _showExamDetailsDialog(BuildContext context) {
    const textStyle = TextStyle(color: Colors.black87);
    const hintStyle = TextStyle(color: Colors.grey);

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
                _buildInput(_examNameController, "Exam Name", textStyle, hintStyle),
                const SizedBox(height: 10),
                _buildInput(_topicController, "Topic Name", textStyle, hintStyle),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildInput(_durationController, "Duration", textStyle, hintStyle)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildInput(_marksController, "Marks", textStyle, hintStyle)),
                  ],
                ),
                const SizedBox(height: 10),
                _buildInput(_watermarkController, "Watermark Text", textStyle, hintStyle),
                const SizedBox(height: 10),
                TextField(
                  controller: _instructionsController,
                  maxLines: 4,
                  style: textStyle,
                  decoration: InputDecoration(labelText: "Instructions", labelStyle: hintStyle, border: const OutlineInputBorder()),
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
                _generateSplitPdf(context); // 🔥 Call the PDF Generator
              },
              child: const Text("Generate PDF"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInput(TextEditingController ctrl, String label, TextStyle txt, TextStyle lbl) {
    return TextField(
      controller: ctrl,
      style: txt,
      decoration: InputDecoration(labelText: label, labelStyle: lbl, border: const OutlineInputBorder()),
    );
  }

  // 🔥 CORE PDF GENERATOR (NO TEMPLATE NEEDED)
  Future<void> _generateSplitPdf(BuildContext context) async {
    try {
      final pdf = pw.Document();

      // 1. Load Fonts (Hindi ke liye Hind font zaroori hai)
      final font = await PdfGoogleFonts.hindRegular();
      final boldFont = await PdfGoogleFonts.hindSemiBold(); // Hindi Bold

      // 2. Variables from Admin Input
      final examName = _examNameController.text.toUpperCase();
      final topicName = _topicController.text;
      final time = _durationController.text;
      final marks = _marksController.text;
      final watermark = _watermarkController.text.toUpperCase();
      final instructions = _instructionsController.text.split('\n');
      final date = "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}";

      // 3. Styles
      final headerStyle = pw.TextStyle(font: boldFont, fontSize: 20);
      final subHeaderStyle = pw.TextStyle(font: font, fontSize: 12);
      final textStyle = pw.TextStyle(font: font, fontSize: 10);
      
      // Watermark Widget
      pw.Widget buildWatermark() {
        return pw.Center(
          child: pw.Transform.rotate(
            angle: -0.5,
            child: pw.Opacity(
              opacity: 0.08, // Very light
              child: pw.Text(watermark, style: pw.TextStyle(font: boldFont, fontSize: 70, color: PdfColors.grey)),
            ),
          ),
        );
      }

      // --- PAGE 1: COVER PAGE (Single Column) ---
      pdf.addPage(
        pw.Page(
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
                    
                    // Meta Details Box
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
                    pw.Text("INSTRUCTIONS / निर्देश:", style: pw.TextStyle(font: boldFont, fontSize: 14, decoration: pw.TextDecoration.underline)),
                    pw.SizedBox(height: 10),
                    
                    ...instructions.map((inst) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 5),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("• ", style: boldFont),
                          pw.Expanded(child: pw.Text(inst, style: textStyle)),
                        ],
                      ),
                    )),

                    pw.Spacer(),
                    pw.Center(child: pw.Text("--- Paper Starts on Next Page ---", style: pw.TextStyle(font: font, fontStyle: pw.FontStyle.italic))),
                  ],
                ),
              ],
            );
          },
        ),
      );

      // --- PAGE 2+: QUESTIONS (Split Column Logic) ---
      // Hum Page ki width calculate karke Wrap use karenge columns banane ke liye
      
      final double pageWidth = PdfPageFormat.a4.width - 60; // 30 margin each side
      final double colWidth = (pageWidth - 20) / 2; // 20 gap beech me

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(30),
          build: (context) {
            return [
              pw.Wrap(
                spacing: 20, // Gap between Left & Right Column
                runSpacing: 15, // Gap between Question 1 & 2
                children: List.generate(finalQuestions.length, (index) {
                  final q = finalQuestions[index];
                  return pw.Container(
                    width: colWidth, // 🔥 Force width to half page
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Question Text (Hindi Font ke sath)
                        pw.Text("Q${index + 1}. ${q.questionText}", style: pw.TextStyle(font: boldFont, fontSize: 10)),
                        pw.SizedBox(height: 3),
                        
                        // Options
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
            buildBackground: (context) => buildWatermark(), // Har page par watermark
          ),
        ),
      );

      // 4. Download & Open
      final output = await pdf.save();
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/ExamPaper_Final.pdf');
      await file.writeAsBytes(output);

      await Share.shareXFiles([XFile(file.path)], text: 'Generated PDF Paper');

    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("PDF Error: $e")));
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

              // PDF Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: () => _checkPremiumAndAction(context),
                  icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  label: const Text("Download PDF Paper"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
