import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';

class AdminQuestionBankScreen extends StatefulWidget {
  const AdminQuestionBankScreen({super.key});

  @override
  State<AdminQuestionBankScreen> createState() => _AdminQuestionBankScreenState();
}

class _AdminQuestionBankScreenState extends State<AdminQuestionBankScreen> {
  // --- Selection Variables ---
  String? selectedSubjectId;
  String? selectedSubjectName;
  String? selectedTopicId;
  String? selectedTopicName;

  // --- Controllers for NEW Creation ---
  final TextEditingController _newSubjectController = TextEditingController();
  final TextEditingController _newTopicController = TextEditingController();

  // --- Controllers for Manual Question ---
  final TextEditingController _qTextController = TextEditingController();
  final TextEditingController _optAController = TextEditingController();
  final TextEditingController _optBController = TextEditingController();
  final TextEditingController _optCController = TextEditingController();
  final TextEditingController _optDController = TextEditingController();
  final TextEditingController _optEController = TextEditingController(); // Optional 5th
  final TextEditingController _explanationController = TextEditingController();
  
  int _correctIndex = 0;
  String _difficulty = 'Medium'; // Default
  bool _isSaving = false;

  // --- 1. ADD NEW SUBJECT ---
  void _addNewSubject() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add New Subject"),
        content: TextField(controller: _newSubjectController, decoration: const InputDecoration(labelText: "Subject Name")),
        actions: [
          ElevatedButton(
            onPressed: () async {
              if (_newSubjectController.text.isNotEmpty) {
                String name = _newSubjectController.text.trim();
                DocumentReference ref = await FirebaseFirestore.instance.collection('bank_subjects').add({
                  'name': name,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                setState(() {
                  selectedSubjectId = ref.id;
                  selectedSubjectName = name;
                  selectedTopicId = null; // Reset topic
                });
                _newSubjectController.clear();
                Navigator.pop(ctx);
              }
            },
            child: const Text("Create"),
          )
        ],
      ),
    );
  }

  // --- 2. ADD NEW TOPIC ---
  void _addNewTopic() {
    if (selectedSubjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select a Subject first!")));
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Add Topic to '$selectedSubjectName'"),
        content: TextField(controller: _newTopicController, decoration: const InputDecoration(labelText: "Topic Name")),
        actions: [
          ElevatedButton(
            onPressed: () async {
              if (_newTopicController.text.isNotEmpty) {
                String name = _newTopicController.text.trim();
                DocumentReference ref = await FirebaseFirestore.instance.collection('bank_topics').add({
                  'name': name,
                  'subjectId': selectedSubjectId,
                  'subjectName': selectedSubjectName,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                setState(() {
                  selectedTopicId = ref.id;
                  selectedTopicName = name;
                });
                _newTopicController.clear();
                Navigator.pop(ctx);
              }
            },
            child: const Text("Create"),
          )
        ],
      ),
    );
  }

  // --- 3. SAVE MANUAL QUESTION ---
  Future<void> _saveManualQuestion() async {
    if (selectedSubjectId == null || selectedTopicId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select Subject & Topic")));
      return;
    }
    if (_qTextController.text.isEmpty || _optAController.text.isEmpty || _optBController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Question and at least 2 options required")));
      return;
    }

    setState(() => _isSaving = true);

    try {
      List<String> options = [
        _optAController.text.trim(),
        _optBController.text.trim(),
        _optCController.text.trim(),
        _optDController.text.trim(),
      ];
      if (_optEController.text.isNotEmpty) options.add(_optEController.text.trim());

      // Filter empty options
      options = options.where((e) => e.isNotEmpty).toList();

      await FirebaseFirestore.instance.collection('bank_questions').add({
        'subjectId': selectedSubjectId,
        'subjectName': selectedSubjectName,
        'topicId': selectedTopicId,
        'topicName': selectedTopicName,
        'questionText': _qTextController.text.trim(),
        'options': options,
        'correctAnswerIndex': _correctIndex,
        'explanation': _explanationController.text.trim(),
        'difficulty': _difficulty,
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saved to Question Bank! ✅"), backgroundColor: Colors.green));
      _clearForm();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _clearForm() {
    _qTextController.clear();
    _optAController.clear(); _optBController.clear(); _optCController.clear(); _optDController.clear(); _optEController.clear();
    _explanationController.clear();
    setState(() { _correctIndex = 0; });
  }

  // --- 4. UPLOAD CSV ---
  Future<void> _pickAndUploadCsv() async {
    if (selectedSubjectId == null || selectedTopicId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select Subject & Topic first!")));
      return;
    }

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result != null) {
      setState(() => _isSaving = true);
      try {
        final file = File(result.files.single.path!);
        final input = file.openRead();
        final fields = await input.transform(utf8.decoder).transform(const CsvToListConverter()).toList();

        // Batch write for speed
        WriteBatch batch = FirebaseFirestore.instance.batch();
        int count = 0;

        // Skip Header Row (Index 0) - Start from 1
        for (int i = 1; i < fields.length; i++) {
          var row = fields[i];
          // CSV Format: Question, OptA, OptB, OptC, OptD, CorrectIndex (0-3), Explanation, Difficulty
          if (row.length < 6) continue; // Skip invalid rows

          DocumentReference docRef = FirebaseFirestore.instance.collection('bank_questions').doc();
          
          List<String> options = [
            row[1].toString(), row[2].toString(), row[3].toString(), row[4].toString()
          ];
          
          batch.set(docRef, {
            'subjectId': selectedSubjectId,
            'subjectName': selectedSubjectName,
            'topicId': selectedTopicId,
            'topicName': selectedTopicName,
            'questionText': row[0].toString(),
            'options': options,
            'correctAnswerIndex': int.tryParse(row[5].toString()) ?? 0,
            'explanation': row.length > 6 ? row[6].toString() : "",
            'difficulty': row.length > 7 ? row[7].toString() : "Medium",
            'createdAt': FieldValue.serverTimestamp(),
          });
          
          count++;
          // Commit batch every 400 writes (limit is 500)
          if (count % 400 == 0) {
            await batch.commit();
            batch = FirebaseFirestore.instance.batch();
          }
        }
        await batch.commit(); // Final commit

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$count questions uploaded successfully!"), backgroundColor: Colors.green));

      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("CSV Error: $e"), backgroundColor: Colors.red));
      } finally {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ADMIN Question Bank 🏦"),
        backgroundColor: Colors.red.shade900,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- SECTION 1: SELECTORS ---
            const Text("1. Select/Create Hierarchy", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            
            // Subject Dropdown
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('bank_subjects').orderBy('name').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const LinearProgressIndicator();
                var subjects = snapshot.data!.docs;
                
                return Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Select Subject"),
                        value: selectedSubjectId,
                        items: subjects.map((doc) => DropdownMenuItem(
                          value: doc.id,
                          child: Text(doc['name']),
                        )).toList(),
                        onChanged: (val) {
                          setState(() {
                            selectedSubjectId = val;
                            selectedSubjectName = subjects.firstWhere((d) => d.id == val)['name'];
                            selectedTopicId = null; // Reset topic when subject changes
                            selectedTopicName = null;
                          });
                        },
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.add_box, color: Colors.blue, size: 30), onPressed: _addNewSubject)
                  ],
                );
              },
            ),
            const SizedBox(height: 15),

            // Topic Dropdown (Dependent on Subject)
            if (selectedSubjectId != null)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('bank_topics')
                    .where('subjectId', isEqualTo: selectedSubjectId)
                    .orderBy('name').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();
                  var topics = snapshot.data!.docs;

                  return Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Select Topic"),
                          value: selectedTopicId,
                          items: topics.map((doc) => DropdownMenuItem(
                            value: doc.id,
                            child: Text(doc['name']),
                          )).toList(),
                          onChanged: (val) {
                            setState(() {
                              selectedTopicId = val;
                              selectedTopicName = topics.firstWhere((d) => d.id == val)['name'];
                            });
                          },
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.add_box, color: Colors.orange, size: 30), onPressed: _addNewTopic)
                    ],
                  );
                },
              ),

            const Divider(height: 40, thickness: 2),

            // --- SECTION 2: ADD QUESTION ---
            if (selectedSubjectId != null && selectedTopicId != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("2. Add Question", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ElevatedButton.icon(
                    onPressed: _pickAndUploadCsv, 
                    icon: const Icon(Icons.upload_file), 
                    label: const Text("Upload CSV"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  )
                ],
              ),
              const SizedBox(height: 15),

              // Manual Entry Form
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      TextField(
                        controller: _qTextController, 
                        maxLines: 3, 
                        decoration: const InputDecoration(labelText: "Question Text", border: OutlineInputBorder())
                      ),
                      const SizedBox(height: 10),
                      
                      // Options
                      ...List.generate(4, (index) => _buildOptionField(index)),
                      TextField(
                        controller: _optEController,
                        decoration: const InputDecoration(labelText: "Option E (Optional)", prefixIcon: Icon(Icons.radio_button_unchecked)),
                      ),
                      
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _difficulty,
                              items: ['Easy', 'Medium', 'Hard'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                              onChanged: (v) => setState(() => _difficulty = v!),
                              decoration: const InputDecoration(labelText: "Difficulty"),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _explanationController,
                              decoration: const InputDecoration(labelText: "Explanation (Optional)"),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveManualQuestion,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800, foregroundColor: Colors.white),
                          child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text("SAVE TO BANK"),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ] else 
              const Center(child: Text("Select Subject & Topic to start adding questions", style: TextStyle(color: Colors.grey))),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionField(int index) {
    List<TextEditingController> controllers = [_optAController, _optBController, _optCController, _optDController];
    List<String> labels = ["A", "B", "C", "D"];
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Radio<int>(
            value: index, 
            groupValue: _correctIndex, 
            onChanged: (v) => setState(() => _correctIndex = v!),
            activeColor: Colors.green,
          ),
          Expanded(
            child: TextField(
              controller: controllers[index],
              decoration: InputDecoration(
                labelText: "Option ${labels[index]}",
                isDense: true,
                border: const OutlineInputBorder()
              ),
            ),
          ),
        ],
      ),
    );
  }
}
