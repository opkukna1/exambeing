import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

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

  // 🔒 SECURITY CHECK
  Future<void> _checkPermissions() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) { _showErrorAndExit("Please login first."); return; }

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return;
      
      String isHost = (userDoc['host'] ?? 'no').toString().toLowerCase();
      if (isHost != 'yes') { _showErrorAndExit("Access Denied: You are not a Host."); return; }

      DocumentSnapshot weekDoc = await FirebaseFirestore.instance
          .collection('study_schedules').doc(widget.examId)
          .collection('weeks').doc(widget.weekId).get();
      
      if (!weekDoc.exists) { _showErrorAndExit("Week not found."); return; }

      String creatorId = weekDoc['createdBy'] ?? ''; 
      if (creatorId != user.uid) { _showErrorAndExit("Access Denied: You can only add tests to your own schedules."); return; }

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

  // 🔥 POWERFUL REGEX CLEANER
  // Database se aane wale text se (Exam : ... Year : ...) remove karega
  // Lekin Original Database ko update nahi karega
  String _cleanText(String text) {
    // Regex Logic:
    // \s* -> Shuru ke spaces
    // \(  -> Bracket start
    // .*? -> Beech ka kuch bhi content (Non-greedy)
    // (Exam|Year|SSC|RPSC|UPSC|Govt|RAS|IAS|Bank) -> In shabdon se shuru hone wala
    // \)  -> Bracket close
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
                      'question': qController.text, // Ye Text Local hai, DB change nahi hoga
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

  // 🔥 FETCH LOGIC WITH CLEANING
  Future<void> _fetchQuestionsFromSelection() async {
    setState(() => _isGenerating = true);
    List<Map<String, dynamic>> fetchedQuestions = [];
    try {
      List<Future<void>> tasks = [];
      for (var entry in _topicCounts.entries) {
        for (int i = 0; i < entry.value; i++) {
          tasks.add(Future(() async {
            String randomId = FirebaseFirestore.instance.collection('questions').doc().id;
            var query = await FirebaseFirestore.instance.collection('questions').where('topicId', isEqualTo: entry.key).orderBy(FieldPath.documentId).startAt([randomId]).limit(1).get();
            if (query.docs.isNotEmpty) { _processFetchedDoc(query.docs.first, fetchedQuestions); } 
            else { var startQuery = await FirebaseFirestore.instance.collection('questions').where('topicId', isEqualTo: entry.key).limit(1).get(); if (startQuery.docs.isNotEmpty) _processFetchedDoc(startQuery.docs.first, fetchedQuestions); }
          }));
        }
      }
      await Future.wait(tasks);
      setState(() { _questions.addAll(fetchedQuestions); _isGenerating = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Fetched ${fetchedQuestions.length} questions!")));
    } catch (e) {
      setState(() => _isGenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _processFetchedDoc(QueryDocumentSnapshot doc, List<Map<String, dynamic>> list) {
    var data = doc.data() as Map<String, dynamic>;
    
    // 🔥 CLEANING HAPPENS HERE (No DB Change)
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

    // Check uniqueness using Cleaned Question
    if (!_questions.any((q) => q['question'] == cleanedQ) && !list.any((q) => q['question'] == cleanedQ)) {
      list.add({ 
        'question': cleanedQ, // Cleaned Text Added to Local List
        'options': options, 
        'correctIndex': data['correctAnswerIndex'] ?? data['correctIndex'] ?? 0, 
        'explanation': explanation, 
        'id': doc.id 
      });
    }
  }

  void _saveTest() async {
    if (_testTitleController.text.isEmpty || _unlockTime == null || _questions.isEmpty || _contactController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Title, Time, Contact No. & Questions required!"))); return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('study_schedules').doc(widget.examId).collection('weeks').doc(widget.weekId).collection('tests').add({
        'testTitle': _testTitleController.text.trim(), 'unlockTime': Timestamp.fromDate(_unlockTime!), 'questions': _questions, 'createdAt': FieldValue.serverTimestamp(), 'createdBy': user.uid, 'contactNumber': _contactController.text.trim(), 'attemptedUsers': [],
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
                    ElevatedButton.icon(onPressed: _isGenerating ? null : _openAutoGeneratorSheet, style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple.shade50, foregroundColor: Colors.deepPurple), icon: _isGenerating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome), label: const Text("Auto Gen")),
                ])
            ]),
            const Divider(),
            
            _questions.isEmpty 
            ? const Padding(padding: EdgeInsets.all(20), child: Center(child: Text("No questions added.")))
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
                         // 🔥 EDIT BUTTON
                         IconButton(
                           icon: const Icon(Icons.edit, color: Colors.blue), 
                           onPressed: () => _showManualQuestionDialog(existingQ: q, index: i)
                         ),
                         // DELETE BUTTON
                         IconButton(
                           icon: const Icon(Icons.delete, color: Colors.red), 
                           onPressed: () => setState(() => _questions.removeAt(i))
                         ),
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
