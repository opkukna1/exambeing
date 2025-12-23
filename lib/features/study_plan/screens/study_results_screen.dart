import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
// ✅ IMPORT PRINTING PACKAGE
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

// ✅ IMPORT THE NEW SOLUTION SCREEN
import 'test_solution_screen.dart'; 

class StudyResultsScreen extends StatelessWidget {
  final String examId;
  final String examName;

  const StudyResultsScreen({super.key, required this.examId, required this.examName});

  // 🔥 PDF GENERATION LOGIC STARTS HERE
  Future<void> _generateAndPrintPdf(BuildContext context, Map<String, dynamic> resultData, String examTitle) async {
    try {
      // 1. Data Preparation
      List<dynamic> rawList = resultData['questionsSnapshot'] ?? [];
      List<Map<String, dynamic>> questions = List<Map<String, dynamic>>.from(
         rawList.map((x) => Map<String, dynamic>.from(x))
      );
      
      double score = (resultData['score'] as num).toDouble();
      int correct = resultData['correct'] ?? 0;
      int wrong = resultData['wrong'] ?? 0;

      // 2. HTML Content Builder
      StringBuffer html = StringBuffer();
      
      html.write("""
        <!DOCTYPE html>
        <html>
        <head>
          <style>
            body { font-family: sans-serif; color: #333; }
            .cover-page { 
              height: 90vh; 
              display: flex; 
              flex-direction: column; 
              justify-content: center; 
              align-items: center; 
              text-align: center;
              border: 5px double #673AB7;
              padding: 20px;
            }
            .logo { font-size: 50px; font-weight: bold; color: #673AB7; margin-bottom: 20px; }
            .exam-title { font-size: 30px; margin-bottom: 10px; }
            .score-box { 
              font-size: 40px; 
              font-weight: bold; 
              color: white; 
              background-color: #673AB7; 
              padding: 20px 40px; 
              border-radius: 50px; 
              margin: 20px 0;
            }
            .stats { font-size: 18px; color: #555; margin-top: 10px; }
            
            .page-break { page-break-after: always; }
            
            .question-container { 
              border: 1px solid #ddd; 
              padding: 15px; 
              margin-bottom: 15px; 
              border-radius: 8px;
              page-break-inside: avoid; /* Try not to split questions across pages */
              background-color: #fff;
            }
            .q-text { font-size: 16px; font-weight: bold; margin-bottom: 10px; }
            .option { padding: 5px; margin: 2px 0; font-size: 14px; }
            .user-ans { color: #1565C0; font-weight: bold; } /* Blue for user selection */
            .correct-ans { color: #2E7D32; font-weight: bold; } /* Green for correct */
            .wrong-ans { color: #C62828; text-decoration: line-through; } /* Red for wrong */
            
            .explanation-box { 
              background-color: #f3e5f5; 
              padding: 10px; 
              margin-top: 10px; 
              border-left: 4px solid #673AB7; 
              font-size: 13px;
            }
            .status-badge {
              float: right;
              font-size: 12px;
              padding: 2px 8px;
              border-radius: 4px;
              color: white;
            }
            .badge-correct { background-color: green; }
            .badge-wrong { background-color: red; }
            .badge-skipped { background-color: orange; }
          </style>
        </head>
        <body>
      """);

      // --- PAGE 1: COVER PAGE ---
      html.write("""
        <div class="cover-page">
          <div class="logo">Exambeing</div>
          <div class="exam-title">$examTitle</div>
          <div>Solution & Analysis Key</div>
          <div class="score-box">Score: ${score.toStringAsFixed(1)}</div>
          <div class="stats">
            Correct: $correct | Wrong: $wrong
          </div>
          <p style="margin-top:50px; font-size:12px; color:#999;">Generated on ${DateFormat('dd MMM yyyy').format(DateTime.now())}</p>
        </div>
        <div class="page-break"></div>
      """);

      // --- PAGE 2+: QUESTIONS ---
      // Loop through questions
      for (int i = 0; i < questions.length; i++) {
        var q = questions[i];
        String questionText = q['question'] ?? 'No Question Text';
        String explanation = q['explanation'] ?? 'No explanation available.';
        String correctOption = q['correctOption'] ?? '';
        String userSelected = q['selectedOption'] ?? ''; // Can be null or empty if skipped

        // Logic to determine status
        bool isSkipped = userSelected.isEmpty;
        bool isCorrect = userSelected == correctOption;
        
        String badgeHtml = "";
        if (isSkipped) {
          badgeHtml = '<span class="status-badge badge-skipped">Skipped</span>';
        } else if (isCorrect) {
          badgeHtml = '<span class="status-badge badge-correct">Correct</span>';
        } else {
          badgeHtml = '<span class="status-badge badge-wrong">Wrong</span>';
        }

        // Add page break logic manually every 4 questions to ensure clean split
        // (Though existing logic handles overflow, this forces structure as requested)
        if (i > 0 && i % 4 == 0) {
           html.write('<div class="page-break"></div>');
        }

        html.write("""
          <div class="question-container">
            $badgeHtml
            <div class="q-text">Q${i + 1}: $questionText</div>
            <div style="margin-bottom: 8px;">
        """);

        // Options Display logic
        // Assuming options are stored somewhat standardly, usually we display User vs Correct
        html.write("""
              <div class="option"><b>Your Answer:</b> <span class="${isCorrect ? 'correct-ans' : (isSkipped ? '' : 'wrong-ans')}">${isSkipped ? 'Not Attempted' : userSelected}</span></div>
              <div class="option"><b>Correct Answer:</b> <span class="correct-ans">$correctOption</span></div>
            </div>
            <div class="explanation-box">
              <b>Explanation:</b><br/>
              $explanation
            </div>
          </div>
        """);
      }

      html.write("</body></html>");

      // 3. Print/PDF Action
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => await Printing.convertHtml(
          format: format,
          html: html.toString(),
        ),
        name: '${examTitle}_Solutions', // Name of the saved file
      );

    } catch (e) {
      debugPrint("Error generating PDF: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error generating PDF: $e")));
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
                  const SizedBox(height: 5),
                  const Text("Complete a test to see analytics.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            );
          }

          // 📊 Calculate Overall Stats
          double totalScore = 0;
          int totalTests = docs.length;
          for (var doc in docs) {
            totalScore += (doc['score'] as num).toDouble();
          }
          double avgScore = totalTests > 0 ? totalScore / totalTests : 0;

          return Column(
            children: [
              // 📈 SUMMARY CARD
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade700]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.deepPurple.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]
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

              // 📝 LIST OF RESULTS
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    double score = (data['score'] as num).toDouble();
                    
                    // Formatting Date
                    Timestamp? ts = data['attemptedAt'];
                    String dateStr = ts != null 
                      ? DateFormat('dd MMM, hh:mm a').format(ts.toDate()) 
                      : "Just now";

                    return Card(
                      margin: const EdgeInsets.only(bottom: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
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
                            
                            // 👇 ACTION BUTTONS ROW
                            Row(
                              children: [
                                // 1. VIEW SOLUTION BUTTON (Existing)
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.visibility, size: 16),
                                    label: const Text("Analysis"),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.deepPurple,
                                      side: const BorderSide(color: Colors.deepPurple),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                                    ),
                                    onPressed: () {
                                       if (data['questionsSnapshot'] != null) {
                                         // ✅ FIX: Explicitly cast List<dynamic> to List<Map<String, dynamic>>
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
                                       } else {
                                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Analysis not available for this test.")));
                                       }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                
                                // 2. DOWNLOAD PDF BUTTON (🔥 NEW)
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.download, size: 16),
                                    label: const Text("Download PDF"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.deepPurple,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                                    ),
                                    onPressed: () {
                                      if (data['questionsSnapshot'] != null) {
                                        _generateAndPrintPdf(context, data, data['testTitle'] ?? "Test Result");
                                      } else {
                                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Data not available for PDF.")));
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
