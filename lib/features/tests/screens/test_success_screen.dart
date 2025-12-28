import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart'; 
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw; 
import 'package:exambeing/models/question_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Required for user role check

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
  
  // Permission flags
  bool canDownloadPdf = false;
  bool isAdmin = false;
  bool isLoadingPermissions = true;

  // --- ADMIN INPUT CONTROLLERS ---
  final TextEditingController _examNameController = TextEditingController(text: "MOCK TEST SERIES");
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _durationController = TextEditingController(text: "60 Mins");
  final TextEditingController _marksController = TextEditingController();
  final TextEditingController _watermarkController = TextEditingController(text: "EXAMBEING");
  
  @override
  void initState() {
    super.initState();
    _initializeData();
    _checkPermissions();
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

  // 🔒 CHECK PERMISSIONS FROM FIRESTORE
  Future<void> _checkPermissions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (user.email == "opsiddh42@gmail.com") {
        setState(() {
          isAdmin = true;
          canDownloadPdf = true;
          isLoadingPermissions = false;
        });
        return;
      }

      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final data = userDoc.data();
          // Check for 'download' field being 'yes'
          if (data != null && data['download'] == 'yes') {
            setState(() {
              canDownloadPdf = true;
            });
          }
        }
      } catch (e) {
        debugPrint("Error checking permissions: $e");
      }
    }
    setState(() {
      isLoadingPermissions = false;
    });
  }

  // 🧹 CLEAN TEXT FUNCTION (STRONGER REGEX)
  String _cleanQuestionText(String text) {
    // Removes patterns like (Exam: ...), (Year: ...), (SSC ...), etc. at the end of the string
    // Also handles variations in spacing and parenthesis
    return text.replaceAll(RegExp(r'\s*\(.*?(Exam|Year|SSC|RPSC|UPSC|Bank|Railway).*?\)\s*$', caseSensitive: false), '').trim();
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
                _buildInput(_examNameController, "Exam Name (e.g. RAJASTHAN POLICE)"),
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
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(context);
                _printHtml(isAnswerKey: false);
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

  // 🔥 CORE FUNCTION: HTML TO PDF
  Future<void> _printHtml({required bool isAnswerKey}) async {
    setState(() => isGenerating = true);

    try {
      final examName = _examNameController.text.toUpperCase();
      final topicName = _topicController.text;
      final watermarkText = _watermarkController.text.toUpperCase();
      final totalQs = finalQuestions.length;

      // ------------------------------------
      // 1. CSS STYLES
      // ------------------------------------
      String htmlContent = """
      <!DOCTYPE html>
      <html lang="hi">
      <head>
        <meta charset="UTF-8">
        <link href="https://fonts.googleapis.com/css2?family=Noto+Sans+Devanagari:wght@400;700;800&family=Arimo:wght@400;700&display=swap" rel="stylesheet">
        <style>
            @page { 
                size: A4; 
                margin-top: 20mm; 
                margin-bottom: 15mm; 
                margin-left: 15mm; 
                margin-right: 15mm; 
            }
            
            * { box-sizing: border-box; -webkit-print-color-adjust: exact; print-color-adjust: exact; }

            body { 
                background-color: white; 
                font-family: 'Arimo', sans-serif; 
                margin: 0; padding: 0;
            }

            .hindi-font { font-family: 'Noto Sans Devanagari', sans-serif; }
            
            /* WATERMARK */
            .watermark {
                position: fixed; top: 50%; left: 50%;
                transform: translate(-50%, -50%) rotate(-45deg);
                font-size: 80px; color: rgba(0,0,0,0.04);
                font-weight: bold; z-index: -1000;
                white-space: nowrap; pointer-events: none;
            }

            /* --- COVER PAGE --- */
            .a4-page {
                width: 100%;
                min-height: 90vh;
                position: relative;
                page-break-after: always; 
            }

            .header-grid {
                display: flex; justify-content: space-between; align-items: flex-start;
                border-bottom: 2px solid #000; padding-bottom: 15px; margin-bottom: 10px;
            }
            .header-left { font-size: 14px; font-weight: bold; line-height: 1.5; width: 30%; }
            .header-center { text-align: center; width: 40%; display: flex; flex-direction: column; align-items: center; }
            .header-right { text-align: right; width: 30%; display: flex; flex-direction: column; align-items: flex-end; justify-content: flex-end; }

            .exam-name-box {
                border: 2px solid #000; font-size: 20px; font-weight: 800; padding: 8px 15px;
                border-radius: 4px; margin-bottom: 5px; font-family: 'Noto Sans Devanagari', sans-serif;
                background-color: #f9f9f9; text-transform: uppercase;
            }
            .paper-title { font-size: 18px; font-weight: bold; margin-top: 5px; text-transform: uppercase; }

            .warning-box {
                border: 1px solid #000; padding: 10px; margin: 15px 0;
                font-size: 11.5px; line-height: 1.4; text-align: justify;
            }

            .instructions-container {
                display: flex; gap: 20px; border-top: 2px solid #000; border-bottom: 2px solid #000; margin-top: 10px;
            }
            .col { flex: 1; padding: 10px 0; }
            .col-left { border-right: 1px solid #000; padding-right: 15px; }
            .col-right { padding-left: 5px; }
            .col-header { text-align: center; font-weight: bold; text-decoration: underline; margin-bottom: 12px; font-size: 15px; }
            .instruction-list { font-size: 11px; line-height: 1.35; padding-left: 18px; text-align: justify; }
            .instruction-list li { margin-bottom: 6px; }

            .footer-warning {
                font-size: 10px; font-weight: bold; margin-top: 10px; text-align: justify;
                border-bottom: 1px solid #000; padding-bottom: 8px;
            }
            .bottom-text { font-size: 10px; margin-top: 8px; font-family: 'Noto Sans Devanagari', sans-serif; }
            .page-footer { display: flex; justify-content: space-between; align-items: center; margin-top: 25px; font-weight: bold; }

            /* --- QUESTIONS PAGE CSS --- */
            .questions-page { width: 100%; }
            .page-header { font-size: 10px; text-align: center; color: grey; margin-bottom: 10px; border-bottom: 1px solid #ccc; }
            .questions-wrapper { column-count: 2; column-gap: 30px; column-rule: 1px solid #ddd; width: 100%; }
            .question-box { break-inside: avoid; page-break-inside: avoid; margin-bottom: 15px; padding-bottom: 10px; border-bottom: 1px dotted #ccc; }
            .q-text { font-weight: bold; font-size: 13px; margin-bottom: 5px; }
            .options-list { margin-left: 10px; font-size: 12px; }
            .option-item { margin-bottom: 2px; }
            
            /* ANSWER KEY STYLES */
            .correct-option { font-weight: bold; color: black; }
            .explanation-box {
                margin-top: 5px;
                padding: 5px;
                background-color: #f0f0f0;
                font-size: 11px;
                border-left: 2px solid #333;
            }
        </style>
      </head>
      <body>
         <div class="watermark">$watermarkText</div>
      """;

      // ------------------------------------
      // 2. CONTENT GENERATION
      // ------------------------------------
      
      // HEADER PAGE (Common for both Paper and Answer Key now, but title changes slightly for key if desired)
      String displayTitle = isAnswerKey ? "$examName - ANSWER KEY & EXPL" : "$examName";
      
      htmlContent += """
      <div class="a4-page">
          <div class="header-grid">
              <div class="header-left hindi-font">
                  पुस्तिका में प्रश्नों की संख्या : $totalQs<br>
                  No. of Questions in Booklet : $totalQs<br>
                  <div style="margin-top: 15px; font-size: 16px;">Paper Code : <b>${isAnswerKey ? 'KEY-01' : '01'}</b></div>
              </div>

              <div class="header-center">
                  <div class="exam-name-box">$displayTitle</div>
                  <div class="paper-title">$topicName</div>
              </div>

              <div class="header-right">
                  <div style="height: 40px;"></div>
                  <div class="hindi-font" style="font-size: 10px; margin-top: 25px; text-align: right;">
                      प्रश्न पुस्तिका संख्या व बारकोड /<br>
                      Question Booklet No. & Barcode
                  </div>
              </div>
          </div>

          <div class="warning-box hindi-font">
              प्रश्न पुस्तिका के पेपर की सील/पॉलिथिन बैग को खोलने पर प्रश्न पत्र हल करने से पूर्व परीक्षार्थी यह सुनिश्चित कर लें कि :-
              <ul style="padding-left: 20px; margin: 4px 0;">
                  <li>प्रश्न पुस्तिका संख्या तथा ओ.एम.आर. उत्तर-पत्रक पर अंकित बारकोड संख्या समान है।</li>
                  <li>सभी $totalQs प्रश्न सही मुद्रित हैं।</li>
              </ul>
              किसी भी प्रकार की विसंगति या दोषपूर्ण होने पर परीक्षार्थी वीक्षक से दूसरी प्रश्न पुस्तिका प्राप्त कर लें। यह सुनिश्चित करने की जिम्मेदारी अभ्यर्थी की होगी।<br>
              <span style="font-family: 'Arimo', sans-serif; display: block; margin-top: 8px;">
              On opening the paper seal/polythene bag of the Question Booklet before attempting the question paper the candidate should ensure that:-
              <ul style="padding-left: 20px; margin: 4px 0;">
                  <li>Question Booklet Number and Barcode Number of OMR Answer Sheet are same.</li>
                  <li>All pages & Questions of Question Booklet and OMR Answer Sheet are properly printed.</li>
              </ul>
              If there is any discrepancy/defect, candidate must obtain another Question Booklet from Invigilator.
              </span>
          </div>

          <div class="instructions-container">
              <div class="col col-left hindi-font">
                  <div class="col-header">परीक्षार्थियों के लिए निर्देश</div>
                  <ol class="instruction-list">
                      <li>प्रत्येक प्रश्न के लिये एक विकल्प भरना अनिवार्य है।</li>
                      <li>सभी प्रश्नों के अंक समान हैं।</li>
                      <li>एक से अधिक उत्तर देने की दशा में प्रश्न के उत्तर को गलत माना जाएगा।</li>
                      <li><b>OMR उत्तर-पत्रक</b> में केवल <b>नीले बॉल पॉइंट पेन</b> से विवरण भरें।</li>
                      <li>कृपया अपना रोल नम्बर ओ.एम.आर. उत्तर-पत्रक पर सावधानीपूर्वक सही भरें।</li>
                      <li>ओ.एम.आर. उत्तर-पत्रक में करेक्शन पेन/व्हाइटनर/ब्लेड का उपयोग निषिद्ध है।</li>
                      <li><b>प्रत्येक गलत उत्तर के लिए प्रश्न अंक का 1/3 भाग काटा जायेगा।</b></li>
                      <li>प्रत्येक प्रश्न के पाँच विकल्प दिए गये हैं (A, B, C, D, E)।</li>
                      <li><b>यदि आप प्रश्न का उत्तर नहीं देना चाहते हैं, तो उत्तर-पत्रक में पांचवें (E) विकल्प को गहरा करें।</b> यदि पांच में से कोई भी गोला गहरा नहीं किया जाता है, तो <b>1/3 भाग काटा जायेगा।</b></li>
                      <li>मोबाइल फोन अथवा इलेक्ट्रॉनिक यंत्र का परीक्षा हॉल में प्रयोग पूर्णतया वर्जित है।</li>
                  </ol>
              </div>

              <div class="col col-right">
                  <div class="col-header">INSTRUCTIONS FOR CANDIDATES</div>
                  <ol class="instruction-list">
                      <li>It is mandatory to fill one option for each question.</li>
                      <li>All questions carry equal marks.</li>
                      <li>If more than one answer is marked, it would be treated as wrong answer.</li>
                      <li>Fill in the particulars carefully with <b>BLUE BALL POINT PEN</b> only.</li>
                      <li>Please correctly fill your Roll Number in OMR Answer Sheet.</li>
                      <li>Use of Correction Pen/Whitener in the OMR Answer Sheet is strictly forbidden.</li>
                      <li><b>1/3 part of the mark(s) of each question will be deducted for each wrong answer.</b></li>
                      <li>Each question has five options marked as A, B, C, D, E.</li>
                      <li><b>If you are not attempting a question, then you have to darken the circle 'E'. If none of the five circles is darkened, 1/3 part of the marks shall be deducted.</b></li>
                      <li>Mobile Phone or any other electronic gadget is strictly prohibited.</li>
                  </ol>
              </div>
          </div>

          <div class="footer-warning">
              <b>Warning:</b> If a candidate is found copying, F.I.R. would be lodged against him/her under <b>Rajasthan Public Examination Act, 2022</b>.
          </div>

          <div class="bottom-text">
              उत्तर-पत्रक में दो प्रतियां हैं - मूल प्रति और कार्बन प्रति। परीक्षा समाप्ति पर परीक्षा कक्ष छोड़ने से पूर्व परीक्षार्थी उत्तर-पत्रक की दोनों प्रतियां वीक्षक को सौंपेंगे।
          </div>

          <div class="page-footer">
              <div style="font-size: 24px;">00 - 🌑</div>
              <div>[ QR CODE ]</div>
          </div>
      </div>
      """;

      // --- QUESTIONS LIST (Format is same for both, Answer Key just adds styling and explanation) ---
      htmlContent += """
      <div class="questions-page">
      <div class="page-header">$examName - $topicName ${isAnswerKey ? '(Solution)' : ''}</div>
      <div class="questions-wrapper">
      """;

      List<String> labels = ["(A)", "(B)", "(C)", "(D)"];

      for (int i = 0; i < finalQuestions.length; i++) {
        final q = finalQuestions[i];
        String displayQuestion = _cleanQuestionText(q.questionText);
        
        String optionsHtml = "<div class='options-list'>";
        for(int j=0; j<q.options.length; j++) {
          if(j < 4) {
            String optionText = q.options[j];
            String prefix = "";
            String cssClass = "option-item";

            // 🔥 MARK CORRECT ANSWER IN ANSWER KEY MODE
            if (isAnswerKey && j == q.correctAnswerIndex) {
              prefix = "✅ "; // Right Check Mark
              cssClass += " correct-option"; // Bold Style
            }

            optionsHtml += "<div class='$cssClass'>$prefix<b>${labels[j]}</b> $optionText</div>";
          }
        }
        optionsHtml += "<div class='option-item'><b>(E)</b> अनुतरित प्रश्न</div>";
        optionsHtml += "</div>";

        // 🔥 ADD EXPLANATION IN ANSWER KEY MODE
        String explanationHtml = "";
        if (isAnswerKey && q.explanation.isNotEmpty) {
          explanationHtml = """
          <div class="explanation-box">
            <b>Explanation:</b> ${q.explanation}
          </div>
          """;
        }

        htmlContent += """
        <div class="question-box">
          <div class="q-text">Q${i+1}. $displayQuestion</div>
          $optionsHtml
          $explanationHtml
        </div>
        """;
      }
      htmlContent += "</div></div>";

      htmlContent += "</body></html>";

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => await Printing.convertHtml(
          format: format,
          html: htmlContent,
        ),
        name: isAnswerKey ? 'Solution_Paper' : 'Question_Paper',
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
        String displayQ = _cleanQuestionText(q.questionText);
        csvData += "${clean(displayQ)},${q.options.map(clean).join(',')},${clean(q.options[q.correctAnswerIndex])}\n";
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
      body: isLoadingPermissions 
        ? const Center(child: CircularProgressIndicator()) 
        : Center(
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

              // ATTEMPT BUTTON (Always visible)
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                  onPressed: () => context.push('/practice-mcq', extra: {'questions': finalQuestions, 'topicName': finalTopicName, 'mode': 'test'}),
                  child: const Text("ATTEMPT TEST NOW"),
                ),
              ),
              const SizedBox(height: 20), const Divider(), const SizedBox(height: 10),
              
              if (canDownloadPdf || isAdmin) ...[
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
                  
                  // BUTTON 2: Answer Key with Explanation
                  SizedBox(width: double.infinity, child: OutlinedButton.icon(
                    onPressed: () => _printHtml(isAnswerKey: true), 
                    icon: const Icon(Icons.check_circle_outline, color: Colors.orange),
                    label: const Text("Print Answer Key (With Expl)"),
                  )),
                  const SizedBox(height: 10),

                  // BUTTON 3: CSV (🔥 RESTRICTED TO ADMIN ONLY)
                  if (isAdmin)
                    SizedBox(width: double.infinity, child: OutlinedButton.icon(
                      onPressed: _generateCsv,
                      icon: const Icon(Icons.table_chart, color: Colors.green),
                      label: const Text("Download Excel (CSV)"),
                    )),
                ]
              ] else ...[
                 // Optional: Show a message or just show nothing if user can't download
                 // const Text("Downloads not available for this account.", style: TextStyle(color: Colors.grey, fontSize: 12)),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
