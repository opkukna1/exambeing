import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
// ✅ IMPORT PRINTING & PDF PACKAGES
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

class TestSolutionScreen extends StatefulWidget {
  final String testId;
  final List<Map<String, dynamic>> originalQuestions; 
  final String? examName;

  const TestSolutionScreen({
    super.key, 
    required this.testId, 
    required this.originalQuestions,
    this.examName
  });

  @override
  State<TestSolutionScreen> createState() => _TestSolutionScreenState();
}

class _TestSolutionScreenState extends State<TestSolutionScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _userResultData = {};
  Map<String, dynamic> _userResponses = {}; // Key: QuestionID, Value: SelectedOptionIndex

  @override
  void initState() {
    super.initState();
    _fetchUserResult();
  }

  Future<void> _fetchUserResult() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('test_results')
          .doc(widget.testId)
          .get();

      if (doc.exists) {
        if (mounted) {
          setState(() {
            _userResultData = doc.data() as Map<String, dynamic>;
            _userResponses = Map<String, dynamic>.from(_userResultData['userResponse'] ?? {});
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching result: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Helper to ensure Options are List<String>
  List<String> _getOptions(Map<String, dynamic> q) {
    if (q['options'] != null && (q['options'] as List).isNotEmpty) {
      return List<String>.from(q['options']);
    }
    List<String> opts = [];
    for (int i = 0; i < 6; i++) {
      if (q.containsKey('option$i')) opts.add(q['option$i'].toString());
    }
    return opts;
  }

  // 🔥🔥🔥 PDF GENERATOR FUNCTION (HTML BASED) 🔥🔥🔥
  Future<void> _generateAndPrintPdf(BuildContext context) async {
    try {
      // 1. Prepare Data
      double score = (_userResultData['score'] ?? 0).toDouble();
      int correct = _userResultData['correct'] ?? 0;
      int wrong = _userResultData['wrong'] ?? 0;
      int skipped = _userResultData['skipped'] ?? 0;
      String examTitle = widget.examName ?? "Test Solution";

      StringBuffer html = StringBuffer();

      // --- HTML HEAD & CSS ---
      html.write("""
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="UTF-8">
          <style>
            body { font-family: sans-serif; padding: 20px; color: #333; }
            
            /* COVER PAGE */
            .cover-page {
              height: 90vh;
              display: flex;
              flex-direction: column;
              justify-content: center;
              align-items: center;
              text-align: center;
              border: 5px double #673AB7;
              border-radius: 20px;
            }
            .brand { font-size: 50px; font-weight: bold; color: #673AB7; margin-bottom: 10px; }
            .title { font-size: 30px; font-weight: bold; margin-bottom: 20px; text-decoration: underline; }
            .score-box { background-color: #673AB7; color: white; padding: 20px 40px; border-radius: 50px; font-size: 40px; font-weight: bold; margin: 30px 0; }
            .stats { font-size: 20px; margin-top: 10px; }
            .green-text { color: green; font-weight: bold; }
            .red-text { color: red; font-weight: bold; }
            .orange-text { color: orange; font-weight: bold; }
            
            .page-break { page-break-after: always; }
            
            /* QUESTION BOX */
            .q-box {
              border: 1px solid #ccc;
              border-radius: 10px;
              padding: 15px;
              margin-bottom: 20px;
              background-color: #fff;
              box-shadow: 0 2px 5px rgba(0,0,0,0.1);
              page-break-inside: avoid;
            }
            .q-header { display: flex; justify-content: space-between; border-bottom: 1px solid #eee; padding-bottom: 5px; margin-bottom: 10px; }
            .q-num { font-weight: bold; color: #673AB7; font-size: 18px; }
            .q-text { font-size: 16px; margin-bottom: 10px; font-weight: 500; }
            
            /* TABLE STYLE FOR OPTIONS */
            .opt-table { width: 100%; border-collapse: collapse; margin-top: 10px; }
            .opt-table td { padding: 8px; border: 1px solid #eee; vertical-align: middle; }
            .opt-label { font-weight: bold; width: 40px; background-color: #f5f5f5; text-align: center;}
            
            .correct-row { background-color: #e8f5e9; border: 1px solid green; } /* Light Green */
            .wrong-row { background-color: #ffebee; border: 1px solid red; }   /* Light Red */
            
            .status-badge { padding: 4px 8px; border-radius: 4px; color: white; font-size: 12px; }
            .badge-correct { background-color: green; }
            .badge-wrong { background-color: red; }
            .badge-skipped { background-color: orange; }

            .exp-box { background-color: #fff9c4; padding: 10px; margin-top: 10px; border-left: 4px solid #fbc02d; font-size: 14px; }
          </style>
        </head>
        <body>
      """);

      // --- COVER PAGE CONTENT ---
      html.write("""
        <div class="cover-page">
          <div class="brand">Exambeing</div>
          <div class="title">$examTitle</div>
          <div class="score-box">Score: ${score.toStringAsFixed(1)}</div>
          <div class="stats">
            <span class="green-text">Correct: $correct</span> &nbsp;|&nbsp; 
            <span class="red-text">Wrong: $wrong</span> &nbsp;|&nbsp; 
            <span class="orange-text">Skipped: $skipped</span>
          </div>
          <p style="margin-top:50px; color:#777;">Generated on ${DateFormat('dd MMM yyyy').format(DateTime.now())}</p>
        </div>
        <div class="page-break"></div>
      """);

      // --- QUESTIONS LOOP ---
      for (int i = 0; i < widget.originalQuestions.length; i++) {
        var q = widget.originalQuestions[i];
        String questionText = q['question'] ?? q['questionText'] ?? 'No Question';
        String explanation = q['explanation'] ?? q['solution'] ?? 'No explanation available.';
        List<String> options = _getOptions(q);
        int correctIndex = q['correctIndex'] ?? q['correctAnswerIndex'] ?? 0;
        String qId = q['id'] ?? "q_$i";
        
        // Determine Status
        int? userIdx = _userResponses[qId];
        bool isSkipped = userIdx == null;
        bool isCorrect = userIdx == correctIndex;
        
        String statusLabel = isSkipped ? "Skipped" : (isCorrect ? "Correct" : "Wrong");
        String badgeClass = isSkipped ? "badge-skipped" : (isCorrect ? "badge-correct" : "badge-wrong");

        html.write("""
          <div class="q-box">
            <div class="q-header">
              <span class="q-num">Q${i + 1}</span>
              <span class="status-badge $badgeClass">$statusLabel</span>
            </div>
            <div class="q-text">$questionText</div>
            
            <table class="opt-table">
        """);

        // Options Rows
        for (int j = 0; j < options.length; j++) {
           String rowStyle = "";
           String mark = "";
           String userLabel = "";
           
           if (j == correctIndex) {
             rowStyle = 'class="correct-row"'; // Always green for correct
             mark = "✅";
           } else if (j == userIdx && !isCorrect) {
             rowStyle = 'class="wrong-row"'; // Red for user's wrong choice
             mark = "❌";
           }

           if (j == userIdx) {
             userLabel = "<span style='font-size:12px; font-weight:bold; color:#555;'> (Your Ans)</span>";
           }

           html.write("""
             <tr $rowStyle>
               <td class="opt-label">${String.fromCharCode(65 + j)}</td>
               <td>${options[j]} $mark $userLabel</td>
             </tr>
           """);
        }

        html.write("""
            </table>
            <div class="exp-box">
              <strong>💡 Explanation:</strong><br/>
              $explanation
            </div>
          </div>
        """);
      }

      html.write("</body></html>");

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => await Printing.convertHtml(
          format: format,
          html: html.toString(),
        ),
        name: '${examTitle}_Analysis',
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    // Stats for Header
    int correct = _userResultData['correct'] ?? 0;
    int wrong = _userResultData['wrong'] ?? 0;
    int skipped = _userResultData['skipped'] ?? 0;
    double score = (_userResultData['score'] ?? 0).toDouble();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.examName ?? "Analysis"),
        actions: [
          // 🔥🔥 NEW DOWNLOAD BUTTON 🔥🔥
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: "Download PDF",
            onPressed: () => _generateAndPrintPdf(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // 📊 1. SCORE HEADER
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.deepPurple.shade50),
            child: Column(
              children: [
                Text("Total Score: ${score.toStringAsFixed(1)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatBadge("Correct", correct, Colors.green),
                    _buildStatBadge("Wrong", wrong, Colors.red),
                    _buildStatBadge("Skipped", skipped, Colors.orange),
                  ],
                )
              ],
            ),
          ),

          // 📝 2. QUESTION LIST
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: widget.originalQuestions.length,
              itemBuilder: (context, index) {
                var qData = widget.originalQuestions[index];
                return _buildSolutionCard(qData, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String label, int count, Color color) {
    return Column(
      children: [
        CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Text("$count", style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(fontSize: 12))
      ],
    );
  }

  Widget _buildSolutionCard(Map<String, dynamic> q, int index) {
    String qId = q['id'] ?? "q_$index";
    String questionText = q['question'] ?? q['questionText'] ?? 'No Question';
    List<String> options = _getOptions(q);
    int correctIndex = q['correctIndex'] ?? q['correctAnswerIndex'] ?? 0;
    String explanation = q['explanation'] ?? q['solution'] ?? '';

    int? userSelectedIndex;
    if (_userResponses.containsKey(qId)) {
      userSelectedIndex = _userResponses[qId];
    }

    bool isSkipped = userSelectedIndex == null;
    bool isCorrect = userSelectedIndex == correctIndex;
    Color statusColor = isSkipped ? Colors.orange : (isCorrect ? Colors.green : Colors.red);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: statusColor.withOpacity(0.5))),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Q${index + 1}.", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(child: Text(questionText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
                Icon(
                  isSkipped ? Icons.warning_amber : (isCorrect ? Icons.check_circle : Icons.cancel),
                  color: statusColor,
                )
              ],
            ),
            const SizedBox(height: 15),

            ...List.generate(options.length, (optIndex) {
              bool isThisCorrect = (optIndex == correctIndex);
              bool isThisUserSelected = (optIndex == userSelectedIndex);
              
              Color optColor = Colors.white;
              Color borderColor = Colors.grey.shade300;
              IconData? icon;

              if (isThisCorrect) {
                optColor = Colors.green.shade50;
                borderColor = Colors.green;
                icon = Icons.check_circle;
              } else if (isThisUserSelected) {
                optColor = Colors.red.shade50;
                borderColor = Colors.red;
                icon = Icons.cancel;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: optColor,
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    if (icon != null) Icon(icon, size: 18, color: borderColor) else const SizedBox(width: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(options[optIndex], style: TextStyle(color: Colors.black87, fontWeight: isThisCorrect || isThisUserSelected ? FontWeight.bold : FontWeight.normal))),
                  ],
                ),
              );
            }),

            if (explanation.isNotEmpty) ...[
              const Divider(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("💡 Explanation:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                    const SizedBox(height: 5),
                    Text(explanation, style: const TextStyle(fontSize: 14)),
                  ],
                ),
              )
            ]
          ],
        ),
      ),
    );
  }
}
