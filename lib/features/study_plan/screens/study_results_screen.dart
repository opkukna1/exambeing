import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
// ✅ PDF & PRINTING PACKAGES
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
// Note: Hum 'pdf/widgets.dart' use nahi kar rahe kyunki hum HTML use karenge

// ✅ IMPORT SOLUTION SCREEN
import 'test_solution_screen.dart'; 

class StudyResultsScreen extends StatelessWidget {
  final String examId;
  final String examName;

  const StudyResultsScreen({super.key, required this.examId, required this.examName});

  // 🔥🔥🔥 NEW: HTML BASED PDF GENERATOR (Fixes Hindi Font & Styling) 🔥🔥🔥
  Future<void> _generateAndPrintPdf(BuildContext context, Map<String, dynamic> resultData, String examTitle) async {
    try {
      // 1. Data Setup
      List<dynamic> rawList = resultData['questionsSnapshot'] ?? [];
      List<Map<String, dynamic>> questions = List<Map<String, dynamic>>.from(
         rawList.map((x) => Map<String, dynamic>.from(x))
      );
      
      double score = (resultData['score'] as num).toDouble();
      int correct = resultData['correct'] ?? 0;
      int wrong = resultData['wrong'] ?? 0;
      int skipped = resultData['skipped'] ?? 0;

      // 2. Build HTML String
      StringBuffer html = StringBuffer();

      // --- HTML HEADER & CSS STYLES ---
      html.write("""
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style>
            body { font-family: sans-serif; padding: 20px; color: #333; }
            
            /* COVER PAGE STYLE */
            .cover-page {
              height: 90vh;
              display: flex;
              flex-direction: column;
              justify-content: center;
              align-items: center;
              text-align: center;
              border: 4px double #673AB7;
              border-radius: 20px;
              margin-bottom: 20px;
            }
            .brand-name { font-size: 50px; font-weight: bold; color: #673AB7; margin-bottom: 10px; }
            .exam-name { font-size: 28px; font-weight: bold; margin-bottom: 20px; text-decoration: underline; }
            .score-card {
              background-color: #673AB7;
              color: white;
              padding: 20px 50px;
              border-radius: 50px;
              font-size: 40px;
              font-weight: bold;
              margin: 30px 0;
            }
            .stats-row { font-size: 20px; margin-top: 20px; }
            .stat-green { color: green; font-weight: bold; }
            .stat-red { color: red; font-weight: bold; }
            
            /* PAGE BREAK LOGIC */
            .page-break { page-break-after: always; }
            
            /* QUESTION CARD STYLE */
            .question-box {
              border: 1px solid #ddd;
              border-radius: 10px;
              padding: 15px;
              margin-bottom: 15px;
              background-color: #fff;
              box-shadow: 0 2px 5px rgba(0,0,0,0.05);
              page-break-inside: avoid; /* Important: Prevents question splitting */
            }
            .q-header {
              display: flex;
              justify-content: space-between;
              border-bottom: 2px solid #eee;
              padding-bottom: 8px;
              margin-bottom: 10px;
            }
            .q-num { font-weight: bold; color: #673AB7; font-size: 18px; }
            .q-text { font-size: 16px; margin-bottom: 15px; font-weight: 500; }
            
            /* OPTIONS TABLE STYLE */
            .ans-table { width: 100%; border-collapse: collapse; margin-bottom: 10px; }
            .ans-table td { padding: 8px; border: 1px solid #eee; }
            .label-col { width: 120px; font-weight: bold; background-color: #f9f9f9; }
            
            .text-correct { color: green; font-weight: bold; }
            .text-wrong { color: red; font-weight: bold; text-decoration: line-through; }
            .text-skipped { color: orange; font-weight: bold; }
            
            .explanation {
              background-color: #f0f4c3; /* Light Yellow/Green */
              padding: 10px;
              border-left: 5px solid #afb42b;
              font-size: 14px;
              color: #444;
            }
          </style>
        </head>
        <body>
      """);

      // --- 3. ADD COVER PAGE CONTENT ---
      html.write("""
        <div class="cover-page">
          <div class="brand-name">Exambeing</div>
          <div class="exam-name">$examTitle</div>
          <div class="score-card">Score: ${score.toStringAsFixed(1)}</div>
          <div class="stats-row">
            <span class="stat-green">Correct: $correct</span> &nbsp; | &nbsp; 
            <span class="stat-red">Wrong: $wrong</span> &nbsp; | &nbsp; 
            <span>Skipped: $skipped</span>
          </div>
          <p style="margin-top:50px; color:#888;">Generated on ${DateFormat('dd MMM yyyy').format(DateTime.now())}</p>
        </div>
        <div class="page-break"></div>
      """);

      // --- 4. LOOP THROUGH QUESTIONS ---
      for (int i = 0; i < questions.length; i++) {
        var q = questions[i];
        String questionText = q['question'] ?? 'Question not found';
        String explanation = q['explanation'] ?? 'No explanation available.';
        String correctOption = q['correctOption'] ?? '';
        String userSelected = q['selectedOption'] ?? ''; 
        
        bool isSkipped = userSelected.isEmpty;
        bool isCorrect = userSelected == correctOption;

        // Logic for User Answer Display
        String userAnsHtml;
        if (isSkipped) {
          userAnsHtml = '<span class="text-skipped">Not Attempted ⚠️</span>';
        } else if (isCorrect) {
          userAnsHtml = '<span class="text-correct">$userSelected ✅</span>';
        } else {
          userAnsHtml = '<span class="text-wrong">$userSelected</span> ❌ <span style="color:red; font-size:12px;">(Wrong)</span>';
        }

        html.write("""
          <div class="question-box">
            <div class="q-header">
              <span class="q-num">Question ${i + 1}</span>
              <span>${isCorrect ? '✅ +Marks' : (isSkipped ? '⚠️ 0 Marks' : '❌ -Marks')}</span>
            </div>
            
            <div class="q-text">$questionText</div>
            
            <table class="ans-table">
              <tr>
                <td class="label-col">Your Answer:</td>
                <td>$userAnsHtml</td>
              </tr>
              <tr>
                <td class="label-col">Correct Ans:</td>
                <td><span class="text-correct">$correctOption ✅</span></td>
              </tr>
            </table>

            <div class="explanation">
              <strong>💡 Explanation:</strong><br/>
              $explanation
            </div>
          </div>
        """);
      }

      html.write("</body></html>");

      // 5. Convert HTML to PDF & Open Print Dialog
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => await Printing.convertHtml(
          format: format,
          html: html.toString(),
        ),
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
                                        // 🔥 CALLING THE NEW HTML GENERATOR
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
