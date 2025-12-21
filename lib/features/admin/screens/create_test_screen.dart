import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 🔥 Auth Import
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
  DateTime? _unlockTime;

  // --- ⚙️ Exam Settings ---
  int _durationMinutes = 60;   
  double _positiveMark = 4.0;  
  double _negativeMark = 1.0;  
  double _skipMark = 0.0;      

  double get _totalMaxMarks => _questions.length * _positiveMark;

  List<Map<String, dynamic>> _questions = [];
  bool _isGenerating = false; 
  bool _isLoadingPage = true; // 🔥 Page Loading State for Security Check

  // --- Auto Generator State ---
  final Map<String, int> _topicCounts = {}; 
  int get _totalSelectedQuestions => _topicCounts.values.fold(0, (sum, count) => sum + count);

  @override
  void initState() {
    super.initState();
    _checkPermissions(); // 🔥 Security Check Start
  }

  // 🔒 SECURITY CHECK FUNCTION
  Future<void> _checkPermissions() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showErrorAndExit("Please login first.");
      return;
    }

    try {
      // 1. Check if User is HOST
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        _showErrorAndExit("User data not found.");
        return;
      }
      
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      String isHost = (userData['host'] ?? 'no').toString().toLowerCase();

      if (isHost != 'yes') {
        _showErrorAndExit("Access Denied: You are not a Host.");
        return;
      }

      // 2. Check if Schedule was CREATED BY this user
      DocumentSnapshot scheduleDoc = await FirebaseFirestore.instance.collection('study_schedules').doc(widget.examId).get();
      
      if (!scheduleDoc.exists) {
        _showErrorAndExit("Schedule not found.");
        return;
      }

      Map<String, dynamic> scheduleData = scheduleDoc.data() as Map<String, dynamic>;
      
      // 🔥 'createdBy' field check (Make sure you save this when creating schedule)
      String creatorId = scheduleData['createdBy'] ?? ''; 
      
      if (creatorId != user.uid) {
        _showErrorAndExit("Access Denied: You can only add tests to your own schedules.");
        return;
      }

      // ✅ All Checks Passed
      if (mounted) {
        setState(() {
          _isLoadingPage = false;
        });
      }

    } catch (e) {
      _showErrorAndExit("Error checking permissions: $e");
    }
  }

  void _showErrorAndExit(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
    Navigator.pop(context); // Go Back
  }

  // ---------------------------------------------------
  // UI HELPERS (Unchanged)
  // ---------------------------------------------------

  void _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      TimeOfDay? time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
      if (time != null) {
        setState(() {
          _unlockTime = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
        });
      }
    }
  }

  void _showManualQuestionDialog({Map<String, dynamic>? existingQ, int? index}) {
    final qController = TextEditingController(text: existingQ?['question'] ?? '');
    final optA = TextEditingController(text: existingQ?['options']?[0] ?? '');
    final optB = TextEditingController(text: existingQ?['options']?[1] ?? '');
    final optC = TextEditingController(text: existingQ?['options']?[2] ?? '');
    final optD = TextEditingController(text: existingQ?['options']?[3] ?? '');
    int correctIndex = existingQ?['correctIndex'] ?? 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(existingQ == null ? "Add Manually" : "Edit Question"),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(controller: qController, decoration: const InputDecoration(labelText: "Question Text"), maxLines: 2),
                  const SizedBox(height: 10),
                  TextField(controller: optA, decoration: const InputDecoration(labelText: "Option A")),
                  TextField(controller: optB, decoration: const InputDecoration(labelText: "Option B")),
                  TextField(controller: optC, decoration: const InputDecoration(labelText: "Option C")),
                  TextField(controller: optD, decoration: const InputDecoration(labelText: "Option D")),
                  const SizedBox(height: 10),
                  DropdownButton<int>(
                    value: correctIndex,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 0, child: Text("Correct: Option A")),
                      DropdownMenuItem(value: 1, child: Text("Correct: Option B")),
                      DropdownMenuItem(value: 2, child: Text("Correct: Option C")),
                      DropdownMenuItem(value: 3, child: Text("Correct: Option D")),
                    ],
                    onChanged: (v) => setDialogState(() => correctIndex = v!),
                  )
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: () {
                  if (qController.text.isNotEmpty) {
                    Map<String, dynamic> newQ = {
                      'question': qController.text,
                      'options': [optA.text, optB.text, optC.text, optD.text],
                      'correctIndex': correctIndex,
                    };
                    setState(() {
                      if (index != null) {
                        _questions[index] = newQ;
                      } else {
                        _questions.add(newQ);
                      }
                    });
                    Navigator.pop(ctx);
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
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("⚙️ Exam Settings & Marking", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _durationMinutes.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Time (Mins)", filled: true, fillColor: Colors.white, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5)),
                    onChanged: (v) => setState(() => _durationMinutes = int.tryParse(v) ?? 60),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey)),
                    child: Column(
                      children: [
                        const Text("Max Marks", style: TextStyle(fontSize: 10, color: Colors.grey)),
                        Text("${_totalMaxMarks.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                      ],
                    ),
                  ),
                )
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(child: TextFormField(initialValue: _positiveMark.toString(), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Right (+)", filled: true, fillColor: Colors.white, border: OutlineInputBorder()), onChanged: (v) => setState(() => _positiveMark = double.tryParse(v) ?? 4.0))),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(initialValue: _negativeMark.toString(), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Wrong (-)", filled: true, fillColor: Colors.white, border: OutlineInputBorder()), onChanged: (v) => setState(() => _negativeMark = double.tryParse(v) ?? 1.0))),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(initialValue: _skipMark.toString(), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Skip", filled: true, fillColor: Colors.white, border: OutlineInputBorder()), onChanged: (v) => setState(() => _skipMark = double.tryParse(v) ?? 0.0))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------
  // 🤖 AUTO GENERATOR LOGIC
  // ---------------------------------------------------

  void _openAutoGeneratorSheet() {
    _topicCounts.clear(); 
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.85,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.deepPurple.shade50, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("🤖 Auto Generator", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text("Selected: $_totalSelectedQuestions Qs", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('subjects').snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                        var subjects = snapshot.data!.docs;
                        if(subjects.isEmpty) return const Center(child: Text("No Subjects Found"));

                        return ListView.builder(
                          itemCount: subjects.length,
                          itemBuilder: (context, index) {
                            var subDoc = subjects[index];
                            var data = subDoc.data() as Map<String, dynamic>;
                            String subjectName = data['subjectName'] ?? data['name'] ?? 'Unnamed Subject';
                            
                            return ExpansionTile(
                              title: Text(subjectName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              leading: const Icon(Icons.library_books, color: Colors.deepPurple),
                              children: [_buildTopicsList(subDoc.id, setSheetState)],
                            );
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _totalSelectedQuestions > 0 
                          ? () { Navigator.pop(context); _fetchQuestionsFromSelection(); }
                          : null,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                        icon: const Icon(Icons.download),
                        label: Text("FETCH $_totalSelectedQuestions QUESTIONS"),
                      ),
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTopicsList(String subjectId, StateSetter setSheetState) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('topics').where('subjectId', isEqualTo: subjectId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Padding(padding: EdgeInsets.all(10), child: LinearProgressIndicator());
        var topics = snapshot.data!.docs;
        if (topics.isEmpty) return const ListTile(title: Text("No topics", style: TextStyle(fontSize: 12, color: Colors.grey)));

        return Column(
          children: topics.map((topicDoc) {
            var tData = topicDoc.data() as Map<String, dynamic>;
            int count = _topicCounts[topicDoc.id] ?? 0;
            String topicName = tData['topicName'] ?? tData['name'] ?? 'Unnamed Topic';

            return Container(
              color: count > 0 ? Colors.green.shade50 : Colors.transparent,
              child: ListTile(
                dense: true,
                title: Text(topicName),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                      onPressed: () => setSheetState(() {
                        if (count > 0) {
                          _topicCounts[topicDoc.id] = count - 1;
                          if (_topicCounts[topicDoc.id] == 0) _topicCounts.remove(topicDoc.id);
                        }
                      }),
                    ),
                    Text("$count", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                      onPressed: () => setSheetState(() => _topicCounts[topicDoc.id] = count + 5), 
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _fetchQuestionsFromSelection() async {
    setState(() => _isGenerating = true);
    List<Map<String, dynamic>> fetchedQuestions = [];

    try {
      for (var entry in _topicCounts.entries) {
        String topicId = entry.key;
        int countNeeded = entry.value;
        List<Future<void>> tasks = [];

        for (int i = 0; i < countNeeded; i++) {
          tasks.add(Future(() async {
            String randomId = FirebaseFirestore.instance.collection('questions').doc().id;
            var query = await FirebaseFirestore.instance.collection('questions').where('topicId', isEqualTo: topicId).orderBy(FieldPath.documentId).startAt([randomId]).limit(1).get();
            
            if (query.docs.isNotEmpty) {
              _processFetchedDoc(query.docs.first, fetchedQuestions);
            } else {
              var startQuery = await FirebaseFirestore.instance.collection('questions').where('topicId', isEqualTo: topicId).orderBy(FieldPath.documentId).limit(1).get();
              if (startQuery.docs.isNotEmpty) _processFetchedDoc(startQuery.docs.first, fetchedQuestions);
            }
          }));
        }
        await Future.wait(tasks);
      }
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

  void _processFetchedDoc(QueryDocumentSnapshot doc, List<Map<String, dynamic>> list) {
    var data = doc.data() as Map<String, dynamic>;
    String questionText = data['questionText'] ?? data['question'] ?? 'No Question';
    
    List<String> options = [];
    if(data['option0'] != null) options.add(data['option0'].toString());
    if(data['option1'] != null) options.add(data['option1'].toString());
    if(data['option2'] != null) options.add(data['option2'].toString());
    if(data['option3'] != null) options.add(data['option3'].toString());
    if(data['option4'] != null) options.add(data['option4'].toString());

    if(options.isEmpty && data['options'] != null) {
      options = List<String>.from(data['options']);
    }

    bool alreadyExists = _questions.any((q) => q['question'] == questionText) || list.any((q) => q['question'] == questionText);
    
    if (!alreadyExists) {
      list.add({
        'question': questionText,
        'options': options,
        'correctIndex': data['correctAnswerIndex'] ?? data['correctIndex'] ?? 0,
        'id': doc.id
      });
    }
  }

  void _saveTest() async {
    if (_testTitleController.text.isEmpty || _unlockTime == null || _questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Missing Title, Time or Questions!")));
      return;
    }

    // 🔒 Double Check before saving (Just in case)
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
        'createdBy': user.uid, // 🔥 Saving Creator ID for future checks
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

  @override
  Widget build(BuildContext context) {
    // 🔥 Show Loading until Permissions are checked
    if (_isLoadingPage) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 10),
              Text("Verifying Permissions..."),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Create Test 📝")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: _testTitleController, decoration: const InputDecoration(labelText: "Test Title (e.g. Physics Weekly)", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
              title: Text(_unlockTime == null ? "Select Start Date & Time" : "Starts: ${DateFormat('dd MMM - hh:mm a').format(_unlockTime!)}"),
              trailing: const Icon(Icons.calendar_today, color: Colors.deepPurple),
              onTap: _pickDate,
            ),
            const SizedBox(height: 15),
            _buildSettingsCard(),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Questions (${_questions.length})", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _showManualQuestionDialog(),
                      icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                      tooltip: "Add Manually",
                    ),
                    ElevatedButton.icon(
                      onPressed: _isGenerating ? null : _openAutoGeneratorSheet,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple.shade50, foregroundColor: Colors.deepPurple, elevation: 0),
                      icon: _isGenerating 
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                        : const Icon(Icons.auto_awesome, size: 18),
                      label: const Text("Auto Generate"),
                    )
                  ],
                )
              ],
            ),
            const Divider(),
            _questions.isEmpty 
            ? const Padding(padding: EdgeInsets.all(20), child: Center(child: Text("No questions added yet.")))
            : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _questions.length,
              itemBuilder: (ctx, i) {
                var q = _questions[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text("Q${i+1}: ${q['question']}", maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text("Ans: ${q['options'].length > q['correctIndex'] ? q['options'][q['correctIndex']] : 'Error'}"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit, size: 20, color: Colors.blue), onPressed: () => _showManualQuestionDialog(existingQ: q, index: i)),
                        IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), onPressed: () => setState(() => _questions.removeAt(i))),
                      ],
                    ),
                  ),
                );
              },
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
}
