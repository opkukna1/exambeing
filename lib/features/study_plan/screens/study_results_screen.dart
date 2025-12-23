import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
// ✅ PDF PACKAGES
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ✅ IMPORT SOLUTION SCREEN
import 'test_solution_screen.dart'; 

class StudyResultsScreen extends StatelessWidget {
  final String examId;
  final String examName;

  const StudyResultsScreen({super.key, required this.examId, required this.examName});

  // 🔥 PDF GENERATOR FUNCTION
  Future<void> _generateAndPrintPdf(BuildContext context, Map<String, dynamic> resultData, String examTitle) async {
    try {
      final doc = pw.Document();

      // 1. Prepare Data
      List<dynamic> rawList = resultData['questionsSnapshot'] ?? [];
      List<Map<String, dynamic>> questions = List<Map<String, dynamic>>.from(
         rawList.map((x) => Map<String, dynamic>.from(x))
      );
      
      double score = (resultData['score'] as num).toDouble();
      int correct = resultData['correct'] ?? 0;
      int wrong = resultData['wrong'] ?? 0;

      // 2. Create PDF Layout
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              // --- COVER PAGE ---
              pw.Center(
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text("Exambeing", style: pw.TextStyle(fontSize: 40, fontWeight: pw.FontWeight.bold, color: PdfColors.deepPurple)),
                    pw.SizedBox(height: 20),
                    pw.Text(examTitle, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 10),
                    pw.Text("Solution Key & Analysis", style: const pw.TextStyle(fontSize: 18, color: PdfColors.grey)),
                    pw.SizedBox(height: 40),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.deepPurple,
                        borderRadius: pw.BorderRadius.circular(20)
                      ),
                      child: pw.Text("Score: ${score.toStringAsFixed(1)}", style: pw.TextStyle(fontSize: 30, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.SizedBox(height: 20),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text("Correct: $correct", style: pw.TextStyle(color: PdfColors.green, fontSize: 18)),
                        pw.SizedBox(width: 20),
                        pw.Text("Wrong: $wrong", style: pw.TextStyle(color: PdfColors.red, fontSize: 18)),
                      ]
                    ),
                    pw.SizedBox(height: 40),
                    pw.Divider(),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // --- QUESTIONS LIST ---
              ...List.generate(questions.length, (index) {
                var q = questions[index];
                String questionText = q['question'] ?? 'No Question';
                String explanation = q['explanation'] ?? 'No explanation available.';
                String correctOption = q['correctOption'] ?? '';
                String userSelected = q['selectedOption'] ?? ''; 
                bool isSkipped = userSelected.isEmpty;
                bool isCorrect = userSelected == correctOption;

                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 15),
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(8)
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text("Q${index + 1}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.deepPurple)),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: pw.BoxDecoration(
                              color: isSkipped ? PdfColors.orange : (isCorrect ? PdfColors.green : PdfColors.red),
                              borderRadius: pw.BorderRadius.circular(4)
                            ),
                            child: pw.Text(
                              isSkipped ? "Skipped" : (isCorrect ? "Correct" : "Wrong"), 
                              style: const pw.TextStyle(color: PdfColors.white, fontSize: 10)
                            )
                          )
                        ]
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(questionText, style: const pw.TextStyle(fontSize: 12)),
                      pw.Divider(color: PdfColors.grey200),
                      pw.Row(
                        children: [
                          pw.Text("Your Ans: ", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          pw.Text(isSkipped ? "Not Attempted" : userSelected, style: pw.TextStyle(fontSize: 10, color: isCorrect ? PdfColors.green : PdfColors.red)),
                          pw.SizedBox(width: 20),
                          pw.Text("Correct: ", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          pw.Text(correctOption, style: const pw.TextStyle(fontSize: 10, color: PdfColors.green)),
                        ]
                      ),
                      pw.SizedBox(height: 5),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(5),
                        color: PdfColors.grey100,
                        width: double.infinity,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text("Explanation:", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                            pw.Text(explanation, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                          ]
                        )
                      )
                    ]
                  )
                );
              })
            ];
          }
        )
      );

      // 3. Print / Save
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: '${examTitle}_Solutions',
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text("Please Login")));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("My Performance 🏆"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('test_results')
            .orderBy('attemptedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.analytics_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 10),
                  const Text("No tests attempted yet!", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          // Stats Calc
          double totalScore = 0;
          int totalTests = docs.length;
          for (var doc in docs) {
            totalScore += (doc['score'] as num).toDouble();
          }
          double avgScore = totalTests > 0 ? totalScore / totalTests : 0;

          return Column(
            children: [
              // Summary Header
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade700]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildHeaderStat("Total Tests", "$totalTests", Icons.assignment_turned_in),
                    Container(width: 1, height: 40, color: Colors.white30),
                    _buildHeaderStat("Avg. Score", avgScore.toStringAsFixed(1), Icons.bar_chart),
                  ],
                ),
              ),

              // Results List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    double score = (data['score'] as num).toDouble();
                    Timestamp? ts = data['attemptedAt'];
                    String dateStr = ts != null ? DateFormat('dd MMM, hh:mm a').format(ts.toDate()) : "Just now";

                    return Card(
                      margin: const EdgeInsets.only(bottom: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            // Result Info
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(data['testTitle'] ?? "Test", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      const SizedBox(height: 4),
                                      Text(dateStr, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: score >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(20)
                                  ),
                                  child: Text(
                                    "Score: ${score.toStringAsFixed(1)}", 
                                    style: TextStyle(fontWeight: FontWeight.bold, color: score >= 0 ? Colors.green : Colors.red)
                                  ),
                                )
                              ],
                            ),
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatItem(Icons.check_circle, "${data['correct']}", Colors.green, "Correct"),
                                _buildStatItem(Icons.cancel, "${data['wrong']}", Colors.red, "Wrong"),
                                _buildStatItem(Icons.help_outline, "${data['skipped']}", Colors.orange, "Skipped"),
                              ],
                            ),
                            const SizedBox(height: 15),

                            // 🔥🔥 2 BUTTONS: SOLUTIONS & DOWNLOAD 🔥🔥
                            Row(
                              children: [
                                // BUTTON 1: SOLUTIONS
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.deepPurple,
                                      side: const BorderSide(color: Colors.deepPurple),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                                    ),
                                    onPressed: () {
                                       if (data['questionsSnapshot'] != null) {
                                         // Safe Data Parsing
                                         List<dynamic> rawList = data['questionsSnapshot'];
                                         List<Map<String, dynamic>> safeQuestions = List<Map<String, dynamic>>.from(
                                            rawList.map((x) => Map<String, dynamic>.from(x))
                                         );
                                         
                                         Navigator.push(
                                           context, 
                                           MaterialPageRoute(builder: (c) => TestSolutionScreen(
                                             testId: data['testId'] ?? docs[index].id, 
                                             originalQuestions: safeQuestions, 
                                             examName: data['testTitle'],
                                           ))
                                         );
                                       }
                                    },
                                    child: const Text("Solutions"),
                                  ),
                                ),
                                
                                const SizedBox(width: 10), // Gap

                                // BUTTON 2: DOWNLOAD
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.download_rounded, size: 18),
                                    label: const Text("Download"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.deepPurple,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                                    ),
                                    onPressed: () {
                                      if (data['questionsSnapshot'] != null) {
                                        _generateAndPrintPdf(context, data, data['testTitle'] ?? "Result");
                                      } else {
                                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Data missing for PDF.")));
                                      }
                                    },
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String val, Color color, String label) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}
