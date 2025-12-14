import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart'; 
import 'package:exambeing/models/question_model.dart'; // Ensure this path is correct

class TestSuccessScreen extends StatefulWidget {
  final List<Question> questions;
  final String topicName;

  const TestSuccessScreen({
    super.key, 
    required this.questions, 
    required this.topicName
  });

  @override
  State<TestSuccessScreen> createState() => _TestSuccessScreenState();
}

class _TestSuccessScreenState extends State<TestSuccessScreen> {

  @override
  void deactivate() {
    // Screen change hone par purane snackbars hata denge
    ScaffoldMessenger.of(context).clearSnackBars(); 
    super.deactivate();
  }

  // 🔒 1. CHECK PREMIUM & DOWNLOAD
  Future<void> _checkPremiumAndDownload(BuildContext context, {bool withAnswers = false, bool isCsv = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    
    // Agar user login nahi hai to return
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please login first!"))
      );
      return;
    }

    // 1. Show loading dialog
    showDialog(
      context: context, 
      barrierDismissible: false, 
      builder: (c) => const Center(child: CircularProgressIndicator())
    );

    try {
      // 2. Fetch User Data
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      
      // Check if widget is still on screen before popping
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      final data = userDoc.data();
      // Check premium status (assuming 'yes' means active)
      final String paidStatus = data != null && data.containsKey('paid_for_gold') ? data['paid_for_gold'] : 'no';

      if (paidStatus == 'yes') {
        // ✅ PREMIUM USER: Proceed to download
        if (isCsv) {
          await _generateAndShareCsv(context);
        } else {
          await _generateAndShareDocx(context, withAnswers);
        }
      } else {
        // ❌ FREE USER: Show Upgrade Message
        _showPremiumSnackBar(context);
      }
    } catch (e) {
      if (mounted) {
        // Close dialog if still open due to error (safety check)
        if (Navigator.canPop(context)) Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  // Helper function to show Premium message
  void _showPremiumSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).clearSnackBars(); 
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          "Premium feature available for educators only.\nTo buy, contact: 8005576670",
          style: TextStyle(color: Colors.white, fontSize: 14),
        ),
        backgroundColor: Colors.black87,
        duration: const Duration(seconds: 5), 
        action: SnackBarAction(
          label: 'COPY NUMBER',
          textColor: Colors.amber,
          onPressed: () {
            Clipboard.setData(const ClipboardData(text: "8005576670"));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Number copied to clipboard!"))
            );
          },
        ),
      ),
    );
  }

  // 📄 2. GENERATE CSV Function
  Future<void> _generateAndShareCsv(BuildContext context) async {
    try {
      List<List<dynamic>> rows = [];

      // Add Header Row
      rows.add([
        "Question",
        "Option A",
        "Option B",
        "Option C",
        "Option D",
        "Correct Answer",
        "Explanation",
        "Topic Name"
      ]);

      // Add Data Rows
      for (var q in widget.questions) {
        String correctAnswerText = "";
        // Safe check for index bounds
        if (q.options.isNotEmpty && q.correctAnswerIndex >= 0 && q.correctAnswerIndex < q.options.length) {
           correctAnswerText = q.options[q.correctAnswerIndex];
        }

        rows.add([
          q.questionText,
          q.options.isNotEmpty ? q.options[0] : "",
          q.options.length > 1 ? q.options[1] : "",
          q.options.length > 2 ? q.options[2] : "",
          q.options.length > 3 ? q.options[3] : "",
          correctAnswerText, 
          q.explanation, 
          widget.topicName
        ]);
      }

      String csvData = const ListToCsvConverter().convert(rows);

      final directory = await getTemporaryDirectory();
      // Unique filename using timestamp
      final String fileName = "ExamBeing_Data_${DateTime.now().millisecondsSinceEpoch}.csv";
      final File file = File('${directory.path}/$fileName');
      await file.writeAsString(csvData);

      await Share.shareXFiles([XFile(file.path)], text: 'Here is your generated Test CSV');

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error creating CSV: $e")));
      }
    }
  }

  // 📄 3. GENERATE DOCX Function
  Future<void> _generateAndShareDocx(BuildContext context, bool withAnswers) async {
    try {
      StringBuffer buffer = StringBuffer();
      buffer.writeln("<html><body>");
      buffer.writeln("<h1>ExamBeing Test Series</h1>");
      buffer.writeln("<h2>Topic: ${widget.topicName}</h2>"); 
      buffer.writeln("<p>Total Questions: ${widget.questions.length}</p><hr>");

      if (withAnswers) {
        // --- ANSWER KEY VIEW ---
        buffer.writeln("<h3>ANSWER KEY & EXPLANATION</h3>");
        buffer.writeln("<table border='1' cellpadding='5' cellspacing='0' width='100%'>");
        buffer.writeln("<tr style='background-color:#f2f2f2'><th>Q</th><th>Correct Answer</th><th>Explanation</th></tr>");
        
        for (int i = 0; i < widget.questions.length; i++) {
          final q = widget.questions[i];
          String optionLabel = String.fromCharCode(65 + q.correctAnswerIndex); // A, B, C, D
          String answerText = "";
          
          if (q.options.isNotEmpty && q.correctAnswerIndex < q.options.length) {
            answerText = q.options[q.correctAnswerIndex];
          }

          buffer.writeln("<tr>");
          buffer.writeln("<td align='center'>${i + 1}</td>");
          buffer.writeln("<td><b>($optionLabel) $answerText</b></td>");
          buffer.writeln("<td>${q.explanation.isNotEmpty ? q.explanation : 'No explanation'}</td>");
          buffer.writeln("</tr>");
        }
        buffer.writeln("</table>");
      } else {
        // --- QUESTION PAPER VIEW ---
        for (int i = 0; i < widget.questions.length; i++) {
          final q = widget.questions[i];
          buffer.writeln("<div style='margin-bottom: 20px;'>");
          buffer.writeln("<p><b>Q${i + 1}. ${q.questionText}</b></p>");
          buffer.writeln("<ul style='list-style-type: none; padding-left: 0;'>"); // No bullets, simpler format
          if(q.options.isNotEmpty) buffer.writeln("<li>(A) ${q.options[0]}</li>");
          if(q.options.length > 1) buffer.writeln("<li>(B) ${q.options[1]}</li>");
          if(q.options.length > 2) buffer.writeln("<li>(C) ${q.options[2]}</li>");
          if(q.options.length > 3) buffer.writeln("<li>(D) ${q.options[3]}</li>");
          buffer.writeln("</ul></div>");
        }
      }
      buffer.writeln("</body></html>");

      final directory = await getTemporaryDirectory();
      // Unique filename
      final String suffix = withAnswers ? "AnswerKey" : "QuestionPaper";
      final String fileName = "ExamBeing_${suffix}_${DateTime.now().millisecondsSinceEpoch}.doc";
      
      final File file = File('${directory.path}/$fileName');
      await file.writeAsString(buffer.toString());

      await Share.shareXFiles([XFile(file.path)], text: 'Here is your generated $suffix');

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error creating file: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Success"), 
        elevation: 0,
        // Optional: Disable back button logic if you want strict flow
        // automaticallyImplyLeading: false, 
      ),
      body: Center(
        // ✅ Fix: ScrollView added to prevent overflow on small screens
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 80),
              const SizedBox(height: 24),
              const Text(
                "Test Generated Successfully!", 
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold), 
                textAlign: TextAlign.center
              ),
              const SizedBox(height: 10),
              Text(
                "Topic: ${widget.topicName}\nQuestions: ${widget.questions.length}",
                style: const TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // BUTTON 1: Attempt
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple, 
                    foregroundColor: Colors.white, 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 5,
                  ),
                  onPressed: () {
                    // Navigate to Practice/Test Mode
                    context.push('/practice-mcq', extra: {
                      'questions': widget.questions, 
                      'topicName': widget.topicName, 
                      'mode': 'test'
                    });
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 28),
                  label: const Text("ATTEMPT TEST NOW", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              
              const SizedBox(height: 30),
              const Divider(thickness: 1.5),
              const SizedBox(height: 15),
              
              // Premium Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.star, color: Colors.amber),
                  SizedBox(width: 8),
                  Text("Educator Tools (Premium)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                  SizedBox(width: 8),
                  Icon(Icons.star, color: Colors.amber),
                ],
              ),
              const SizedBox(height: 15),

              // BUTTONS: Premium DOCX Row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: const BorderSide(color: Colors.blueAccent)
                      ),
                      onPressed: () => _checkPremiumAndDownload(context, withAnswers: false),
                      icon: const Icon(Icons.print, color: Colors.blue),
                      label: const Text("Paper (Print)"),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: const BorderSide(color: Colors.green)
                      ),
                      onPressed: () => _checkPremiumAndDownload(context, withAnswers: true),
                      icon: const Icon(Icons.vpn_key, color: Colors.green),
                      label: const Text("Answer Key"),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 15),

              // BUTTON: CSV Download Row
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    side: const BorderSide(color: Colors.teal),
                  ),
                  onPressed: () => _checkPremiumAndDownload(context, isCsv: true),
                  icon: const Icon(Icons.table_chart, color: Colors.teal),
                  label: const Text("Export as CSV (Excel)", style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                ),
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
