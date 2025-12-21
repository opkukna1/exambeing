import 'dart:async';
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
  final _contactController = TextEditingController(); // 🔥 NEW: Teacher Contact Number
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

  // 🔒 SECURITY CHECK (Existing Logic)
  Future<void> _checkPermissions() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) { _showErrorAndExit("Please login first."); return; }

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return;
      
      String isHost = (userDoc['host'] ?? 'no').toString().toLowerCase();
      if (isHost != 'yes') { _showErrorAndExit("Access Denied: You are not a Host."); return; }

      // 🔥 FIXED: Check Week Ownership
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

  // 🧹 REGEX CLEANER FUNCTION (Fast)
  String _cleanText(String text) {
    // Ye bracket ke andar wala Exam/Year data hata dega
    return text.replaceAll(RegExp(r'\s*\(\s*(Exam|Year|SSC|RPSC|UPSC|Govt).*?\)', caseSensitive: false), '').trim();
  }

  // ---------------------------------------------------
  // 🤖 FAST AUTO GENERATOR LOGIC
  // ---------------------------------------------------
  Future<void> _fetchQuestionsFromSelection() async {
    setState(() => _isGenerating = true);
    List<Map<String, dynamic>> fetchedQuestions = [];

    try {
      // Parallel Processing ke liye Futures List
      List<Future<void>> tasks = [];

      for (var entry in _topicCounts.entries) {
        String topicId = entry.key;
        int countNeeded = entry.value;

        for (int i = 0; i < countNeeded; i++) {
          tasks.add(Future(() async {
            // Random ID trick for random selection
            String randomId = FirebaseFirestore.instance.collection('questions').doc().id;
            var query = await FirebaseFirestore.instance.collection('questions')
                .where('topicId', isEqualTo: topicId)
                .orderBy(FieldPath.documentId)
                .startAt([randomId])
                .limit(1)
                .get();
            
            if (query.docs.isNotEmpty) {
              _processFetchedDoc(query.docs.first, fetchedQuestions);
            } else {
              // Agar random se nahi mila to shuru se le lo
              var startQuery = await FirebaseFirestore.instance.collection('questions')
                  .where('topicId', isEqualTo: topicId)
                  .limit(1)
                  .get();
              if (startQuery.docs.isNotEmpty) _processFetchedDoc(startQuery.docs.first, fetchedQuestions);
            }
          }));
        }
      }
      
      // Sabko ek sath run karo (Faster)
      await Future.wait(tasks);

      setState(() {
        _questions.addAll(fetchedQuestions);
        _isGenerating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Fetched ${fetchedQuestions.length} questions!")));
    } catch (e) {
      setState(() => _isGenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error fetching: $e")));
    }
  }

  // 🔥 PROCESS DOC (With Regex & Explanation)
  void _processFetchedDoc(QueryDocumentSnapshot doc, List<Map<String, dynamic>> list) {
    var data = doc.data() as Map<String, dynamic>;
    
    // 1. Get & Clean Question
    String rawQ = data['questionText'] ?? data['question'] ?? 'No Question';
    String cleanedQ = _cleanText(rawQ); 

    // 2. Get Explanation (Solution)
    String explanation = data['explanation'] ?? data['solution'] ?? '';

    // 3. Options Logic
    List<String> options = [];
    if(data['option0'] != null) options.add(data['option0'].toString());
    if(data['option1'] != null) options.add(data['option1'].toString());
    if(data['option2'] != null) options.add(data['option2'].toString());
    if(data['option3'] != null) options.add(data['option3'].toString());
    if(data['option4'] != null) options.add(data['option4'].toString());

    if(options.isEmpty && data['options'] != null) {
      options = List<String>.from(data['options']);
    }

    // Duplicate Check
    bool alreadyExists = _questions.any((q) => q['question'] == cleanedQ) || list.any((q) => q['question'] == cleanedQ);
    
    if (!alreadyExists) {
      list.add({
        'question': cleanedQ, // Cleaned Text
        'options': options,
        'correctIndex': data['correctAnswerIndex'] ?? data['correctIndex'] ?? 0,
        'explanation': explanation, // 🔥 Saving Explanation
        'id': doc.id
      });
    }
  }

  // 💾 SAVE TEST FUNCTION
  void _saveTest() async {
    if (_testTitleController.text.isEmpty || _unlockTime == null || _questions.isEmpty || _contactController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Title, Time, Contact No. aur Questions sab zaroori hai!")));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('study_schedules')
          .doc(widget.examId)
          .collection('weeks')
          .doc(widget.weekId)
          .collection('tests')
          .add({
        'testTitle': _testTitleController.text.trim(),
        'unlockTime': Timestamp.fromDate(_unlockTime!),
        'questions': _questions,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user.uid,
        'contactNumber': _contactController.text.trim(), // 🔥 Saving Contact Info
        'attemptedUsers': [],
        'settings': {
          'positive': _positiveMark,
          'negative': _negativeMark,
          'skip': _skipMark,
          'duration': _durationMinutes,
          'totalMaxMarks': _totalMaxMarks,
        }
      });
      if(mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // UI Components
  void _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2030),
    );
    if (picked != null) {
      TimeOfDay? time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
      if (time != null) {
        setState(() => _unlockTime = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute));
      }
    }
  }

  // ... (Manual Question Dialog & Settings Card code remains same, omitted for brevity) ...
  // (Main UI Build)
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
            
            // 🔥 NEW: Contact Number Field
            TextField(
              controller: _contactController, 
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "WhatsApp No. for Students", 
                hintText: "e.g. 8005576670",
                prefixIcon: Icon(Icons.phone, color: Colors.green),
                border: OutlineInputBorder()
              )
            ),
            const SizedBox(height: 10),

            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
              title: Text(_unlockTime == null ? "Select Start Date & Time" : "Starts: ${DateFormat('dd MMM - hh:mm a').format(_unlockTime!)}"),
              trailing: const Icon(Icons.calendar_today, color: Colors.deepPurple),
              onTap: _pickDate,
            ),
            const SizedBox(height: 15),
            
            // ... (Settings Card call) ...
            // Just placeholder for UI logic you already have
            const Card(child: Padding(padding: EdgeInsets.all(16), child: Text("⚙️ Settings (Duration, Marks) loaded..."))), 

            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Questions (${_questions.length})", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _openAutoGeneratorSheet,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple.shade50, foregroundColor: Colors.deepPurple),
                  icon: _isGenerating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome),
                  label: const Text("Auto Generate"),
                )
              ],
            ),
            const Divider(),
            
            // Question List Preview
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _questions.length,
              itemBuilder: (ctx, i) {
                 var q = _questions[i];
                 return Card(
                   child: ListTile(
                     title: Text("Q${i+1}: ${q['question']}", maxLines: 2),
                     subtitle: Text("Ans: ${q['options'][q['correctIndex']]}"),
                     trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => _questions.removeAt(i))),
                   ),
                 );
              }
            ),

            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isGenerating ? null : _saveTest,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, padding: const EdgeInsets.all(16)),
                child: const Text("SAVE FULL TEST", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
  
  // (Auto Generator Sheet function is needed here, paste from previous code or let me know if you need full file)
  void _openAutoGeneratorSheet() { /* Same as before, just uses new _fetchQuestionsFromSelection */ 
    _topicCounts.clear(); 
    showModalBottomSheet(context: context, builder: (c) => Container(child: const Center(child: Text("Topic Selection UI Here")))); // Placeholder
  }
}
