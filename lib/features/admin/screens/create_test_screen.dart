import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';

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
  final Map<String, String> _topicDifficulty = {}; // 🔥 New: Difficulty Map
  bool _useQuestionBank = false; // 🔥 New: Source Switch (False = General, True = Bank)

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
      if (isHost != 'yes' && isHost != 'true') { 
        _showErrorAndExit("Access Denied: You are not a Host."); 
        return; 
      }

      DocumentSnapshot weekDoc = await FirebaseFirestore.instance
          .collection('study_schedules').doc(widget.examId)
          .collection('weeks').doc(widget.weekId).get();
      
      if (!weekDoc.exists) { _showErrorAndExit("Week not found."); return; }

      String creatorId = weekDoc['createdBy'] ?? ''; 
      if (creatorId != user.uid) { 
        _showErrorAndExit("Access Denied: Not your schedule."); 
        return; 
      }

      if (mounted) setState(() => _isLoadingPage = false);

    } catch (e) {
      _showErrorAndExit("Error: $e");
    }
  }

  void _showErrorAndExit(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
    Navigator.pop(context); 
  }

  // --- CSV Logic (Same as before) ---
  void _pickAndParseCSV() async {
    // ... (Old CSV Code remains same - keeping it short here for brevity) ...
    // Just copy the CSV function from previous correct version
  }

  // 🔥 UPDATED: AUTO GENERATOR SHEET (With Source & Difficulty)
  void _openAutoGeneratorSheet() {
    _topicCounts.clear();
    _topicDifficulty.clear();
    
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(builder: (context, setSheetState) {
            
            // Determine Collection Names based on Source
            String subjectCol = _useQuestionBank ? 'bank_subjects' : 'subjects';
            String topicCol = _useQuestionBank ? 'bank_topics' : 'topics';

            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.9, 
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16), 
                    decoration: BoxDecoration(color: _useQuestionBank ? Colors.teal.shade50 : Colors.deepPurple.shade50, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))), 
                    child: Column(
                      children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          const Text("🤖 Auto Generator", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), 
                          Text("Selected: $_totalSelectedQuestions Qs", style: TextStyle(fontWeight: FontWeight.bold, color: _useQuestionBank ? Colors.teal : Colors.deepPurple))
                        ]),
                        const SizedBox(height: 10),
                        // 🔥 SOURCE SWITCH
                        Row(children: [
                          const Text("Source: ", style: TextStyle(fontWeight: FontWeight.bold)),
                          ChoiceChip(label: const Text("General App"), selected: !_useQuestionBank, onSelected: (v) => setSheetState(() => _useQuestionBank = false)),
                          const SizedBox(width: 10),
                          ChoiceChip(label: const Text("Question Bank 🏦"), selected: _useQuestionBank, selectedColor: Colors.teal.shade100, onSelected: (v) => setSheetState(() => _useQuestionBank = true)),
                        ]),
                      ],
                    )
                  ),
                  
                  Expanded(child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection(subjectCol).snapshots(), 
                    builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                        var subjects = snapshot.data!.docs;
                        if(subjects.isEmpty) return const Center(child: Text("No Subjects Found"));
                        
                        return ListView.builder(
                          itemCount: subjects.length, 
                          itemBuilder: (context, index) {
                            var subDoc = subjects[index];
                            var data = subDoc.data() as Map<String, dynamic>;
                            return ExpansionTile(
                              title: Text(data['subjectName'] ?? data['name'] ?? 'Unnamed', style: const TextStyle(fontWeight: FontWeight.bold)), 
                              leading: Icon(Icons.library_books, color: _useQuestionBank ? Colors.teal : Colors.deepPurple), 
                              children: [_buildTopicsList(subDoc.id, topicCol, setSheetState)]
                            );
                          }
                        );
                      }
                  )),
                  
                  Padding(
                    padding: const EdgeInsets.all(16.0), 
                    child: SizedBox(
                      width: double.infinity, 
                      child: ElevatedButton.icon(
                        onPressed: _totalSelectedQuestions > 0 ? () { Navigator.pop(context); _fetchQuestionsFromSelection(); } : null, 
                        style: ElevatedButton.styleFrom(backgroundColor: _useQuestionBank ? Colors.teal : Colors.deepPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)), 
                        icon: const Icon(Icons.download), 
                        label: Text("FETCH $_totalSelectedQuestions QUESTIONS")
                      )
                    )
                  )
                ]
              )
            );
        });
      },
    );
  }

  Widget _buildTopicsList(String subjectId, String collectionName, StateSetter setSheetState) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(collectionName).where('subjectId', isEqualTo: subjectId).snapshots(), 
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Padding(padding: EdgeInsets.all(10), child: LinearProgressIndicator());
        var topics = snapshot.data!.docs;
        if (topics.isEmpty) return const ListTile(title: Text("No topics found"));
        
        return Column(
          children: topics.map((topicDoc) {
            var tData = topicDoc.data() as Map<String, dynamic>;
            int count = _topicCounts[topicDoc.id] ?? 0;
            String diff = _topicDifficulty[topicDoc.id] ?? 'Any'; // Default Any

            return Container(
              color: count > 0 ? (_useQuestionBank ? Colors.teal.shade50 : Colors.deepPurple.shade50) : Colors.transparent, 
              child: Column(
                children: [
                  ListTile(
                    dense: true, 
                    title: Text(tData['topicName'] ?? tData['name'] ?? 'Unnamed'), 
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min, 
                      children: [
                        IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: () => setSheetState(() { if (count > 0) { _topicCounts[topicDoc.id] = count - 1; if (_topicCounts[topicDoc.id] == 0) _topicCounts.remove(topicDoc.id); } })),
                        Text("$count", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.green), onPressed: () => setSheetState(() => _topicCounts[topicDoc.id] = count + 5)),
                      ]
                    )
                  ),
                  // 🔥 Difficulty Selector (Visible only if count > 0)
                  if (count > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(children: [
                        const Text("Difficulty: ", style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(width: 10),
                        _buildDiffChip("Any", diff, topicDoc.id, setSheetState),
                        _buildDiffChip("Easy", diff, topicDoc.id, setSheetState),
                        _buildDiffChip("Medium", diff, topicDoc.id, setSheetState),
                        _buildDiffChip("Hard", diff, topicDoc.id, setSheetState),
                      ]),
                    ),
                  const Divider(height: 1),
                ],
              )
            );
          }).toList()
        );
      }
    );
  }

  Widget _buildDiffChip(String label, String currentVal, String topicId, StateSetter setSheetState) {
    bool isSelected = label == currentVal;
    return GestureDetector(
      onTap: () => setSheetState(() => _topicDifficulty[topicId] = label),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label, style: TextStyle(fontSize: 10, color: isSelected ? Colors.white : Colors.black)),
      ),
    );
  }

  // 🔥 3. FETCH LOGIC (HANDLES BOTH SOURCES & DIFFICULTY)
  Future<void> _fetchQuestionsFromSelection() async {
    setState(() => _isGenerating = true);
    List<Map<String, dynamic>> fetchedQuestions = [];
    String qCollection = _useQuestionBank ? 'bank_questions' : 'questions'; // 🔥 Dynamic Collection
    
    try {
      List<Future<void>> tasks = [];
      
      for (var entry in _topicCounts.entries) {
        String topicId = entry.key;
        int countNeeded = entry.value;
        String difficulty = _topicDifficulty[topicId] ?? 'Any';

        tasks.add(Future(() async {
          Query query = FirebaseFirestore.instance.collection(qCollection).where('topicId', isEqualTo: topicId);
          
          // 🔥 Apply Difficulty Filter
          if (difficulty != 'Any') {
            query = query.where('difficulty', isEqualTo: difficulty);
          }

          // Random Start Logic
          String randomId = FirebaseFirestore.instance.collection(qCollection).doc().id;
          
          // Try fetching with random start
          var snapshot = await query.orderBy(FieldPath.documentId).startAt([randomId]).limit(countNeeded).get();
          List<QueryDocumentSnapshot> docs = snapshot.docs;

          // If not enough, fetch from start
          if (docs.length < countNeeded) {
            int remaining = countNeeded - docs.length;
            var startSnapshot = await query.orderBy(FieldPath.documentId).limit(remaining).get();
            docs.addAll(startSnapshot.docs);
          }

          for (var doc in docs) {
            _processFetchedDoc(doc, fetchedQuestions);
          }
        }));
      }

      await Future.wait(tasks);
      setState(() { _questions.addAll(fetchedQuestions); _isGenerating = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Fetched ${fetchedQuestions.length} questions from ${_useQuestionBank ? 'Bank' : 'General'}!")));
      
    } catch (e) {
      setState(() => _isGenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _processFetchedDoc(QueryDocumentSnapshot doc, List<Map<String, dynamic>> list) {
    var data = doc.data() as Map<String, dynamic>;
    // ... (Same Processing Logic as before) ...
    String rawQ = data['questionText'] ?? data['question'] ?? 'No Question';
    String explanation = data['explanation'] ?? '';
    List<String> options = [];
    if(data['options'] != null) options = List<String>.from(data['options']);

    if (!_questions.any((q) => q['question'] == rawQ) && !list.any((q) => q['question'] == rawQ)) {
      list.add({ 
        'question': rawQ,
        'options': options, 
        'correctIndex': data['correctAnswerIndex'] ?? 0, 
        'explanation': explanation, 
        'id': doc.id 
      });
    }
  }

  // --- Save Logic (Same) ---
  void _saveTest() async {
    // ... (Same Save Logic) ...
    // Just ensure you add this block back
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingPage) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text("Create Test 📝")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ... (Basic Fields) ...
            TextField(controller: _testTitleController, decoration: const InputDecoration(labelText: "Test Title", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _contactController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "WhatsApp No.", hintText: "8005576670", prefixIcon: Icon(Icons.phone), border: OutlineInputBorder())),
            // ...
            const SizedBox(height: 20),
            
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text("Questions (${_questions.length})", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Row(children: [
                    // 🔥 NEW: Auto Gen Button with Icon
                    ElevatedButton.icon(
                      onPressed: _isGenerating ? null : _openAutoGeneratorSheet, 
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.shade50, foregroundColor: Colors.indigo), 
                      icon: const Icon(Icons.smart_toy), 
                      label: const Text("Auto Gen")
                    ),
                ])
            ]),
            const Divider(),
            
            // Question List
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _questions.length,
              itemBuilder: (ctx, i) {
                 var q = _questions[i];
                 return Card(
                   child: ListTile(
                     title: Text("Q${i+1}: ${q['question']}"),
                     subtitle: Text("Ans: ${q['options'].length > q['correctIndex'] ? q['options'][q['correctIndex']] : 'N/A'}"),
                     trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => _questions.removeAt(i))),
                   ),
                 );
              }
            ),

            const SizedBox(height: 30),
            // Save Button
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _questions.isNotEmpty ? () {} : null, child: const Text("SAVE"))) // Placeholder for save
          ],
        ),
      ),
    );
  }
}
