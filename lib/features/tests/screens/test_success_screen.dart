import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard ke liye
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:exambeing/models/question_model.dart';

class TestSuccessScreen extends StatelessWidget {
  final List<Question> questions;
  final String topicName;

  const TestSuccessScreen({
    super.key, 
    required this.questions, 
    required this.topicName
  });

  // 🔒 1. CHECK PREMIUM & DOWNLOAD
  Future<void> _checkPremiumAndDownload(BuildContext context, {bool withAnswers = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Loading dikhao
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      Navigator.pop(context); // Loading hatao

      final data = userDoc.data();
      final String paidStatus = data != null && data.containsKey('paid_for_gold') ? data['paid_for_gold'] : 'no';

      if (paidStatus == 'yes') {
        // 🎉 Premium hai -> Download karwao
        _generateAndShareDocx(context, withAnswers);
      } else {
        // 🔒 Normal User -> Sirf Message dikhao
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "Premium feature available for only educators and coaching institutes.\nFor buy contact our team: 8005576670",
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
    } catch (e) {
      Navigator.pop(context); // Loading hatao
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // 📄 2. GENERATE DOCX (Fixed)
  Future<void> _generateAndShareDocx(BuildContext context, bool withAnswers) async {
    try {
      StringBuffer buffer = StringBuffer();
      buffer.writeln("<html><body>");
      buffer.writeln("<h1>ExamBeing Test Series</h1>");
      buffer.writeln("<h2>Topic: $topicName</h2>");
      buffer.writeln("<p>Total Questions: ${questions.length}</p><hr>");

      if (withAnswers) {
        // ✅ ANSWER KEY (Fixed Error Here)
        buffer.writeln("<h3>ANSWER KEY</h3>");
        buffer.writeln("<table border='1' cellpadding='5'><tr><th>Q No.</th><th>Answer</th></tr>");
        
        for (int i = 0; i < questions.length; i++) {
          final q = questions[i];
          
          // Logic: Index ko A, B, C, D mein badlo aur Text nikalo
          String optionLabel = String.fromCharCode(65 + q.correctAnswerIndex); // 0->A, 1->B
          String answerText = "";
          
          if (q.options.length > q.correctAnswerIndex) {
            answerText = q.options[q.correctAnswerIndex];
          }

          buffer.writeln("<tr><td>${i + 1}</td><td><b>($optionLabel) $answerText</b></td></tr>");
        }
        buffer.writeln("</table>");
      } else {
        // QUESTION PAPER
        for (int i = 0; i < questions.length; i++) {
          final q = questions[i];
          buffer.writeln("<p><b>Q${i + 1}. ${q.questionText}</b></p>");
          buffer.writeln("<ul>");
          if(q.options.isNotEmpty) buffer.writeln("<li>(A) ${q.options[0]}</li>");
          if(q.options.length > 1) buffer.writeln("<li>(B) ${q.options[1]}</li>");
          if(q.options.length > 2) buffer.writeln("<li>(C) ${q.options[2]}</li>");
          if(q.options.length > 3) buffer.writeln("<li>(D) ${q.options[3]}</li>");
          buffer.writeln("</ul><br>");
        }
      }
      buffer.writeln("</body></html>");

      final directory = await getTemporaryDirectory();
      final String fileName = withAnswers ? "AnswerKey.doc" : "QuestionPaper.doc";
      final File file = File('${directory.path}/$fileName');
      await file.writeAsString(buffer.toString());

      await Share.shareXFiles([XFile(file.path)], text: 'Here is your generated ${withAnswers ? "Answer Key" : "Question Paper"}');

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error creating file: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Success"), elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 80),
            const SizedBox(height: 24),
            const Text("Test Generated Successfully!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 40),

            // BUTTON 1: Attempt
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                onPressed: () {
                  context.push('/practice-mcq', extra: {'questions': questions, 'topicName': topicName, 'mode': 'test'});
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text("ATTEMPT TEST NOW", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 20),

            // BUTTONS: Premium DOCX
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                    onPressed: () => _checkPremiumAndDownload(context, withAnswers: false),
                    icon: const Icon(Icons.description, color: Colors.blue),
                    label: const Text("Paper (DOCX)"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                    onPressed: () => _checkPremiumAndDownload(context, withAnswers: true),
                    icon: const Icon(Icons.key, color: Colors.green),
                    label: const Text("Key (DOCX)"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text("DOCX download is a Premium Feature 👑", style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
