import 'dart:async';
import 'dart:convert'; // For CSV
import 'dart:io';      // For File
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart'; // 🔥 Required
import 'package:csv/csv.dart'; // 🔥 Required

class CreateTestScreen extends StatefulWidget {
  final String examId;
  final String weekId;

  const CreateTestScreen({super.key, required this.examId, required this.weekId});

  @override
  State<CreateTestScreen> createState() => _CreateTestScreenState();
}

class _CreateTestScreenState extends State<CreateTestScreen> {
  // --- Basic Info ---
  final _testTitleController = TextEditingController();
  final _contactController = TextEditingController(); 
  DateTime? _unlockTime; 

  // --- Exam Settings ---
  int _durationMinutes = 60;   
  double _positiveMark = 4.0;  
  double _negativeMark = 1.0;  
  double _skipMark = 0.0;       

  double get _totalMaxMarks => _questions.length * _positiveMark;

  List<Map<String, dynamic>> _questions = [];
  bool _isGenerating = false; 
  bool _isLoadingPage = true; 

  // --- Auto Generator State ---
  final Map<String, int> _topicCounts = {}; 
  int get _totalSelectedQuestions => _topicCounts.values.fold(0, (sum, count) => sum + count);

  @override
  void initState() {
    super.initState();
    _checkPermissions(); 
  }

  // 🔒 SECURITY CHECK (Host & Ownership)
  Future<void> _checkPermissions() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) { _showErrorAndExit("Please login first."); return; }

    try {
      // 1. Check if Host
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return;
      
      String isHost = (userDoc['host'] ?? 'no').toString().toLowerCase();
      if (isHost != 'yes' && isHost != 'true') { 
        _showErrorAndExit("Access Denied: You are not a Host."); 
        return; 
      }

      // 2. Check if Week belongs to this Host
      DocumentSnapshot weekDoc = await FirebaseFirestore.instance
          .collection('study_schedules').doc(widget.examId)
          .collection('weeks').doc(widget.weekId).get();
      
      if (!weekDoc.exists) { _showErrorAndExit("Week not found."); return; }

      String creatorId = weekDoc['createdBy'] ?? ''; 
      
      if (creatorId != user.uid) { 
        _showErrorAndExit("Access Denied: You can only add tests to YOUR own schedules."); 
        return; 
      }

      if (mounted) setState(() => _isLoadingPage = false);

    } catch (e) {
      _showErrorAndExit("Error checking permissions: $e");
    }
  }

  void _showErrorAndExit(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
    Navigator.pop(context); 
  }

  // 🔥 UPDATED: CSV PARSER (Fixes "1 Row Found" Issue)
  void _pickAndParseCSV() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        setState(() => _isGenerating = true);
        
        File file = File(result.files.single.path!);
        
        // 1. Read file content safely
        String csvString;
        try {
          csvString = await file.readAsString();
        } catch (e) {
          csvString = await file.readAsString(encoding: latin1);
        }

        // 🔥 FIX: Normalize Newlines (Ye line sabse zaroori hai error hatane ke liye)
        csvString = csvString.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
        
        // 2. Try Standard Comma Parsing
        List<List<dynamic>> fields = const CsvToListConverter(eol: '\n').convert(csvString);

        // Fallback: Agar Comma fail hua (1 column mila), to Semicolon try karo
        if (fields.isNotEmpty && fields[0].length < 2) {
           debugPrint("Comma failed, trying Semicolon...");
           fields = const CsvToListConverter(fieldDelimiter: ';', eol: '\n').convert(csvString);
        }

        if (fields.isEmpty) {
           setState(() => _isGenerating = false);
           _showErrorDialog("File is empty or could not be read.");
           return;
        }

        int addedCount = 0;
        int skippedCount = 0;
        String debugLog = "";

        // Loop starts from 1 (Skipping Header)
        for (int i = 1; i < fields.length; i++) {
          List<dynamic> row = fields[i];
          
          // Basic Validation: Need at least 6 columns
          if (row.length < 6) {
             if (row.isNotEmpty) debugLog += "Row $i skipped: Length ${row.length}\n";
            skippedCount++;
            continue; 
          }

          String question = row[0].toString().trim();
          String optA = row[1].toString().trim();
          String optB = row[2].toString().trim();
          String optC = row[3].toString().trim();
          String optD = row[4].toString().trim();
          String correctAnsRaw = row[5].toString().trim().toUpperCase(); 
          String explanation = row.length > 6 ? row[6].toString().trim() : "";

          if (question.isEmpty || optA.isEmpty) {
            skippedCount++;
            continue;
          }

          int correctIndex = 0;
          if (correctAnsRaw.contains('B') || correctAnsRaw == '2') correctIndex = 1;
          else if (correctAnsRaw.contains('C') || correctAnsRaw == '3') correctIndex = 2;
          else if (correctAnsRaw.contains('D') || correctAnsRaw == '4') correctIndex = 3;

          // Add Unique Question
          if (!_questions.any((q) => q['question'] == question)) {
            _questions.add({
              'id': DateTime.now().millisecondsSinceEpoch.toString() + i.toString(),
              'question': question,
              'options': [optA, optB, optC, optD],
              'correctIndex': correctIndex,
              'explanation': explanation
            });
            addedCount++;
          } else {
            skippedCount++;
          }
        }

        setState(() => _isGenerating = false);

        if (addedCount == 0) {
          _showErrorDialog("Failed to import.\n\nCode found ${fields.length} rows.\n\nDebug Info:\n$debugLog\n\nTip: Make sure you saved as 'CSV (Comma delimited)'.");
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.green, content: Text("Success! Imported $addedCount questions. (Skipped: $skippedCount)")));
        }
      }
    } catch (e) {
      setState(() => _isGenerating = false);
      _showErrorDialog("Error reading CSV: $e");
    }
  }

  void _showErrorDialog(String msg) {
    showDialog(
      context: context, 
      builder: (c) => AlertDialog(
        title: const Text("⚠️ Import Info"),
        content: SingleChildScrollView(child: Text(msg)),
        actions: [TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("OK"))]
      )
    );
  }

  // 🔥 REGEX CLEANER
  String _cleanText(String text) {
    return text.replaceAll(RegExp(r'\s*\(\s*(Exam|Year|SSC|RPSC|UPSC|Govt|RAS|IAS|Bank|Railway|Police).*?\)', caseSensitive: false), '').trim();
  }

  // ✏️ MANUAL ADD / EDIT DIALOG
  void _showManualQuestionDialog({Map<String, dynamic>? existingQ, int? index}) {
    final qController = TextEditingController(text: existingQ?['question'] ?? '');
    final optA = TextEditingController(text: existingQ != null && existingQ['options'].length > 0 ? existingQ['options'][0] : '');
    final optB = TextEditingController(text: existingQ != null && existingQ['options'].length > 1 ? existingQ['options'][1] : '');
    final optC = TextEditingController(text: existingQ != null && existingQ['options'].length > 2 ? existingQ['options'][2] : '');
    final optD = TextEditingController(text: existingQ != null && existingQ['options'].length > 3 ? existingQ['options'][3] : '');
    final explController = TextEditingController(text: existingQ?['explanation'] ?? '');
    
    int correctIndex = existingQ?['correctIndex'] ?? 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(existingQ == null ? "Add Question" : "Edit Question"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: qController, decoration: const InputDecoration(labelText: "Question Text", border: OutlineInputBorder()), maxLines: 3),
                  const SizedBox(height: 10),
                  TextField(controller: optA, decoration: const InputDecoration(labelText: "Option A", prefixIcon: Icon(Icons.looks_one))),
                  TextField(controller: optB, decoration: const InputDecoration(labelText: "Option B", prefixIcon: Icon(Icons.looks_two))),
                  TextField(controller: optC, decoration: const InputDecoration(labelText: "Option C", prefixIcon: Icon(Icons.looks_3))),
                  TextField(controller: optD, decoration: const InputDecoration(labelText: "Option D", prefixIcon: Icon(Icons.looks_4))),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    value: correctIndex,
                    decoration: const InputDecoration(labelText: "Correct Answer", border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text("Option A")),
                      DropdownMenuItem(value: 1, child: Text("Option B")),
                      DropdownMenuItem(value: 2, child: Text("Option C")),
                      DropdownMenuItem(value: 3, child: Text("Option D")),
                    ],
                    onChanged: (v) => setDialogState(() => correctIndex = v!),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: explController, decoration: const InputDecoration(labelText: "Explanation (Solution)", border: OutlineInputBorder()), maxLines: 2),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: () {
                  if (qController.text.isNotEmpty && optA.text.isNotEmpty && optB.text.isNotEmpty) {
                    Map<String, dynamic> newQ = {
                      'question': qController.text,
                      'options': [optA.text, optB.text, optC.text, optD.text],
                      'correctIndex': correctIndex,
                      'explanation': explController.text,
                      'id': existingQ?['id'] ?? DateTime.now().millisecondsSinceEpoch.toString()
                    };

                    setState(() {
                      if (index != null) {
                        _questions[index] = newQ;
                      } else {
                        _questions.add(newQ);
                      }
                    });
                    Navigator.pop(ctx);
                  } else {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Question and Options A, B required")));
                  }
                },
                child: const Text("Save"),
              )
            ],
          );
        },
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Card(
      elevation: 2, color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text("⚙️ Settings", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            const SizedBox(height: 10),
            Row(children: [
                Expanded(child: TextFormField(initialValue: _durationMinutes.toString(), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Time (Mins)", filled: true, fillColor: Colors.white), onChanged: (v) => setState(() => _durationMinutes = int.tryParse(v) ?? 60))),
                const SizedBox(width: 15),
                Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey)), child: Column(children: [const Text("Total Marks", style: TextStyle(fontSize: 10)), Text("${_totalMaxMarks.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green))])))
            ]),
            const SizedBox(height: 10),
            Row(children: [
                Expanded(child: TextFormField(initialValue: _positiveMark.toString(), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Right (+)", filled: true, fillColor: Colors.white), onChanged: (v) => setState(() => _positiveMark = double.tryParse(v) ?? 4.0))),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(initialValue: _negativeMark.toString(), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Wrong (-)", filled: true, fillColor: Colors.white), onChanged: (v) => setState(() => _negativeMark = double.tryParse(v) ?? 1.0))),
            ]),
          ],
        ),
      ),
    );
  }

  void _openAutoGeneratorSheet() {
    _topicCounts.clear(); 
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(builder: (context, setSheetState) {
            return SizedBox(height: MediaQuery.of(context).size.height * 0.85, child: Column(children: [
                  Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.deepPurple.shade50, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("🤖 Auto Generator", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Text("Selected: $_totalSelectedQuestions Qs", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple))])),
                  Expanded(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('subjects').snapshots(), builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                        var subjects = snapshot.data!.docs;
                        if(subjects.isEmpty) return const Center(child: Text("No Subjects Found"));
                        return ListView.builder(itemCount: subjects.length, itemBuilder: (context, index) {
                            var subDoc = subjects[index];
                            var data = subDoc.data() as Map<String, dynamic>;
                            return ExpansionTile(title: Text(data['subjectName'] ?? data['name'] ?? 'Unnamed', style: const TextStyle(fontWeight: FontWeight.bold)), leading: const Icon(Icons.library_books, color: Colors.deepPurple), children: [_buildTopicsList(subDoc.id, setSheetState)]);
                          });
                      })),
                  Padding(padding: const EdgeInsets.all(16.0), child: SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _totalSelectedQuestions > 0 ? () { Navigator.pop(context); _fetchQuestionsFromSelection(); } : null, style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)), icon: const Icon(Icons.download), label: Text("FETCH $_totalSelectedQuestions QUESTIONS"))))
                ]));
        });
      },
    );
  }

  Widget _buildTopicsList(String subjectId, StateSetter setSheetState) {
    return StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('topics').where('subjectId', isEqualTo: subjectId).snapshots(), builder: (context, snapshot) {
        if (!snapshot.hasData) return const Padding(padding: EdgeInsets.all(10), child: LinearProgressIndicator());
        var topics = snapshot.data!.docs;
        if (topics.isEmpty) return const ListTile(title: Text("No topics found"));
        return Column(children: topics.map((topicDoc) {
            var tData = topicDoc.data() as Map<String, dynamic>;
            int count = _topicCounts[topicDoc.id] ?? 0;
            return Container(color: count > 0 ? Colors.green.shade50 : Colors.transparent, child: ListTile(dense: true, title: Text(tData['topicName'] ?? tData['name'] ?? 'Unnamed'), trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: () => setSheetState(() { if (count > 0) { _topicCounts[topicDoc.id] = count - 1; if (_topicCounts[topicDoc.id] == 0) _topicCounts.remove(topicDoc.id); } })),
                    Text("$count", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.green), onPressed: () => setSheetState(() => _topicCounts[topicDoc.id] = count + 5)),
                  ])));
          }).toList());
      });
  }

  // 🔥 2. OPTIMIZED BATCH FETCH LOGIC
  Future<void> _fetchQuestionsFromSelection() async {
    setState(() => _isGenerating = true);
    List<Map<String, dynamic>> fetchedQuestions = [];
    
    try {
      List<Future<void>> tasks = [];
      
      for (var entry in _topicCounts.entries) {
        String topicId = entry.key;
        int countNeeded = entry.value;

        // BATCH QUERY: Fetch 'countNeeded' questions in ONE go
        tasks.add(Future(() async {
          // 1. Generate Random ID
          String randomId = FirebaseFirestore.instance.collection('questions').doc().id;

          // 2. Fetch Batch starting from Random ID
          var querySnapshot = await FirebaseFirestore.instance
              .collection('questions')
              .where('topicId', isEqualTo: topicId)
              .orderBy(FieldPath.documentId)
              .startAt([randomId])
              .limit(countNeeded) // 🔥 FETCH BATCH
              .get();

          List<QueryDocumentSnapshot> docs = querySnapshot.docs;

          // 3. If batch is small (reached end), fetch remaining from start
          if (docs.length < countNeeded) {
            int remaining = countNeeded - docs.length;
            var startSnapshot = await FirebaseFirestore.instance
                .collection('questions')
                .where('topicId', isEqualTo: topicId)
                .orderBy(FieldPath.documentId)
                .limit(remaining)
                .get();
            docs.addAll(startSnapshot.docs);
          }

          // 4. Process all fetched docs
          for (var doc in docs) {
            _processFetchedDoc(doc, fetchedQuestions);
          }
        }));
      }

      await Future.wait(tasks);
      setState(() { _questions.addAll(fetchedQuestions); _isGenerating = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Fetched ${fetchedQuestions.length} questions successfully!")));
      
    } catch (e) {
      setState(() => _isGenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _processFetchedDoc(QueryDocumentSnapshot doc, List<Map<String, dynamic>> list) {
    var data = doc.data() as Map<String, dynamic>;
    
    String rawQ = data['questionText'] ?? data['question'] ?? 'No Question';
    String cleanedQ = _cleanText(rawQ); 
    String explanation = data['explanation'] ?? data['solution'] ?? '';

    List<String> options = [];
    if(data['option0'] != null) options.add(data['option0'].toString());
    if(data['option1'] != null) options.add(data['option1'].toString());
    if(data['option2'] != null) options.add(data['option2'].toString());
    if(data['option3'] != null) options.add(data['option3'].toString());
    if(data['option4'] != null) options.add(data['option4'].toString());
    if(options.isEmpty && data['options'] != null) options = List<String>.from(data['options']);

    if (!_questions.any((q) => q['question'] == cleanedQ) && !list.any((q) => q['question'] == cleanedQ)) {
      list.add({ 
        'question': cleanedQ,
        'options': options, 
        'correctIndex': data['correctAnswerIndex'] ?? data['correctIndex'] ?? 0, 
        'explanation': explanation, 
        'id': doc.id 
      });
    }
  }

  void _saveTest() async {
    // Hide Keyboard First
    FocusScope.of(context).unfocus();

    if (_testTitleController.text.isEmpty || _unlockTime == null || _questions.isEmpty || _contactController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Title, Time, Contact No. & Questions required!"))); return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('study_schedules').doc(widget.examId).collection('weeks').doc(widget.weekId).collection('tests').add({
        'testTitle': _testTitleController.text.trim(),
        'scheduledAt': Timestamp.fromDate(_unlockTime!), 
        'questions': _questions,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user.uid, 
        'contactNumber': _contactController.text.trim(),
        'attemptedUsers': [],
        'settings': { 'positive': _positiveMark, 'negative': _negativeMark, 'skip': _skipMark, 'duration': _durationMinutes, 'totalMaxMarks': _totalMaxMarks }
      });
      if(mounted) Navigator.pop(context);
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"))); }
  }

  void _pickDate() async {
    DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2030));
    if (picked != null) {
      TimeOfDay? time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
      if (time != null) setState(() => _unlockTime = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingPage) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text("Create Test 📝")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: _testTitleController, decoration: const InputDecoration(labelText: "Test Title", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _contactController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "WhatsApp No.", hintText: "8005576670", prefixIcon: Icon(Icons.phone, color: Colors.green), border: OutlineInputBorder())),
            const SizedBox(height: 10),
            ListTile(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)), title: Text(_unlockTime == null ? "Select Start Date & Time" : "Starts: ${DateFormat('dd MMM - hh:mm a').format(_unlockTime!)}"), trailing: const Icon(Icons.calendar_today, color: Colors.deepPurple), onTap: _pickDate),
            const SizedBox(height: 15),
            _buildSettingsCard(),
            const SizedBox(height: 20),
            
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text("Questions (${_questions.length})", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Row(children: [
                    IconButton(onPressed: () => _showManualQuestionDialog(), icon: const Icon(Icons.add_circle, color: Colors.green), tooltip: "Add Manual Question"),
                    
                    // 🔥 CSV BUTTON (Calls Smart Parser)
                    IconButton(onPressed: _isGenerating ? null : _pickAndParseCSV, icon: const Icon(Icons.upload_file, color: Colors.orange), tooltip: "Upload CSV"),
                    
                    ElevatedButton.icon(onPressed: _isGenerating ? null : _openAutoGeneratorSheet, style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple.shade50, foregroundColor: Colors.deepPurple), icon: _isGenerating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome), label: const Text("Auto Gen")),
                ])
            ]),
            const Divider(),
            
            _questions.isEmpty 
            ? const Padding(padding: EdgeInsets.all(20), child: Center(child: Text("No questions added. Upload CSV or Auto Gen.")))
            : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _questions.length,
              itemBuilder: (ctx, i) {
                 var q = _questions[i];
                 return Card(
                   margin: const EdgeInsets.only(bottom: 8),
                   child: ListTile(
                     title: Text("Q${i+1}: ${q['question']}", maxLines: 2, overflow: TextOverflow.ellipsis),
                     subtitle: Text("Ans: ${q['options'][q['correctIndex']]}"),
                     trailing: Row(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showManualQuestionDialog(existingQ: q, index: i)),
                         IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => _questions.removeAt(i))),
                       ],
                     ),
                   ),
                 );
              }
            ),

            const SizedBox(height: 30),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _isGenerating ? null : _saveTest, style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, padding: const EdgeInsets.all(16)), child: const Text("SAVE FULL TEST", style: TextStyle(fontWeight: FontWeight.bold))))
          ],
        ),
      ),
    );
  }
}
