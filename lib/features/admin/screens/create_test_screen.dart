import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CreateTestScreen extends StatefulWidget {
  final String examId;
  final String weekId; // Week ke andar test banega

  const CreateTestScreen({super.key, required this.examId, required this.weekId});

  @override
  State<CreateTestScreen> createState() => _CreateTestScreenState();
}

class _CreateTestScreenState extends State<CreateTestScreen> {
  // --- Basic Info ---
  final _testTitleController = TextEditingController();
  DateTime? _unlockTime;
  int _durationMinutes = 60;

  // --- Marking Scheme ---
  double _positiveMark = 4.0;
  double _negativeMark = 1.0; // Positive value enter karein (e.g. 1 means -1)
  double _skipMark = 0.0;

  // --- Questions Data ---
  List<Map<String, dynamic>> _questions = [];
  bool isLoading = false;

  // --- Hierarchy Logic (To fetch questions) ---
  // (Yahan hum maan rahe hain ki aapke paas ek 'question_bank' collection hai)
  
  // 1️⃣ Pick Date & Time
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

  // 2️⃣ Manually Add Question
  void _showAddQuestionDialog({Map<String, dynamic>? existingQ, int? index}) {
    final qController = TextEditingController(text: existingQ?['question'] ?? '');
    final optA = TextEditingController(text: existingQ?['options'][0] ?? '');
    final optB = TextEditingController(text: existingQ?['options'][1] ?? '');
    final optC = TextEditingController(text: existingQ?['options'][2] ?? '');
    final optD = TextEditingController(text: existingQ?['options'][3] ?? '');
    int correctIndex = existingQ?['correctIndex'] ?? 0; // 0=A, 1=B...

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(existingQ == null ? "Add Question" : "Edit Question"),
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
                        _questions[index] = newQ; // Edit
                      } else {
                        _questions.add(newQ); // Add New
                      }
                    });
                    Navigator.pop(ctx);
                  }
                },
                child: const Text("Save Question"),
              )
            ],
          );
        },
      ),
    );
  }

  // 3️⃣ Dummy Fetch from Database (Replace with actual Query)
  void _fetchFromDatabase() async {
    // Yahan aap 'subject'/'topic' dropdown laga kar database query kar sakte hain
    // Abhi main dummy data add kar raha hu example ke liye
    setState(() {
      _questions.add({
        'question': 'What is the unit of Force?',
        'options': ['Newton', 'Joule', 'Watt', 'Pascal'],
        'correctIndex': 0, // Newton
      });
      _questions.add({
        'question': 'Value of g on Earth?',
        'options': ['9.8 m/s²', '10 m/s²', '8.9 m/s²', 'Zero'],
        'correctIndex': 0, 
      });
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fetched 2 Dummy Questions")));
  }

  // 4️⃣ SAVE TEST TO FIREBASE
  void _saveTest() async {
    if (_testTitleController.text.isEmpty || _unlockTime == null || _questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Title, Time aur Questions zaroori hain!")));
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('study_schedules')
          .doc(widget.examId)
          .collection('weeks')
          .doc(widget.weekId)
          .collection('tests') // New Sub-collection
          .add({
        'testTitle': _testTitleController.text.trim(),
        'unlockTime': Timestamp.fromDate(_unlockTime!),
        'questions': _questions,
        'createdAt': FieldValue.serverTimestamp(),
        'attemptedUsers': [], // List of user IDs jinhone test de diya
        'settings': {
          'positive': _positiveMark,
          'negative': _negativeMark,
          'skip': _skipMark,
          'duration': _durationMinutes,
        }
      });
      if(mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Test 📝")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: _testTitleController, decoration: const InputDecoration(labelText: "Test Title (e.g. Weekly Test 1)")),
            const SizedBox(height: 10),
            ListTile(
              title: Text(_unlockTime == null ? "Select Start Date & Time" : "Start: ${DateFormat('dd MMM - hh:mm a').format(_unlockTime!)}"),
              trailing: const Icon(Icons.access_time),
              tileColor: Colors.grey[200],
              onTap: _pickDate,
            ),
            
            const SizedBox(height: 20),
            const Text("Marking Scheme", style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(child: TextFormField(initialValue: "4", decoration: const InputDecoration(labelText: "Right (+ve)"), onChanged: (v)=> _positiveMark = double.tryParse(v) ?? 4)),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(initialValue: "1", decoration: const InputDecoration(labelText: "Wrong (-ve)"), onChanged: (v)=> _negativeMark = double.tryParse(v) ?? 1)),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(initialValue: "0", decoration: const InputDecoration(labelText: "Skip"), onChanged: (v)=> _skipMark = double.tryParse(v) ?? 0)),
              ],
            ),

            const Divider(height: 30, thickness: 2),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Questions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    IconButton(onPressed: _fetchFromDatabase, icon: const Icon(Icons.download, color: Colors.blue), tooltip: "Fetch from DB"),
                    IconButton(onPressed: () => _showAddQuestionDialog(), icon: const Icon(Icons.add_circle, color: Colors.green), tooltip: "Add Manually"),
                  ],
                )
              ],
            ),

            // List of Questions
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _questions.length,
              itemBuilder: (ctx, i) {
                var q = _questions[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text("Q${i+1}: ${q['question']}"),
                    subtitle: Text("Ans: ${q['options'][q['correctIndex']]}"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => _showAddQuestionDialog(existingQ: q, index: i)),
                        IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => setState(() => _questions.removeAt(i))),
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
                onPressed: _saveTest,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, padding: const EdgeInsets.all(15)),
                child: const Text("SAVE TEST"),
              ),
            )
          ],
        ),
      ),
    );
  }
}
