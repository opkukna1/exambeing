import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart'; // Add uuid package in pubspec.yaml for unique IDs
import '../../../models/test_model.dart'; // Import your model

class CreateTestScreen extends StatefulWidget {
  @override
  _CreateTestScreenState createState() => _CreateTestScreenState();
}

class _CreateTestScreenState extends State<CreateTestScreen> {
  final _formKey = GlobalKey<FormState>();
  String subject = '';
  String topic = '';
  DateTime? scheduledDate;
  TimeOfDay? scheduledTime;
  List<Question> questions = [];

  // Helper to pick date/time
  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (date == null) return;
    
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null) return;

    setState(() {
      scheduledDate = date;
      scheduledTime = time;
    });
  }

  // Function to add a manual question
  void _addQuestionDialog() {
    String qText = '', opA = '', opB = '', opC = '', opD = '', correct = 'A', exp = '';
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Add Question"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(decoration: InputDecoration(labelText: "Question"), onChanged: (v) => qText = v),
              TextField(decoration: InputDecoration(labelText: "Option A"), onChanged: (v) => opA = v),
              TextField(decoration: InputDecoration(labelText: "Option B"), onChanged: (v) => opB = v),
              TextField(decoration: InputDecoration(labelText: "Option C"), onChanged: (v) => opC = v),
              TextField(decoration: InputDecoration(labelText: "Option D"), onChanged: (v) => opD = v),
              DropdownButton<String>(
                value: correct,
                items: ['A', 'B', 'C', 'D'].map((e) => DropdownMenuItem(value: e, child: Text("Correct: $e"))).toList(),
                onChanged: (v) => setState(() => correct = v!),
              ),
              TextField(decoration: InputDecoration(labelText: "Explanation"), onChanged: (v) => exp = v),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                questions.add(Question(
                  id: Uuid().v4(),
                  questionText: qText,
                  optionA: opA, optionB: opB, optionC: opC, optionD: opD,
                  correctOption: correct,
                  explanation: exp
                ));
              });
              Navigator.pop(ctx);
            },
            child: Text("Add"),
          )
        ],
      ),
    );
  }

  void _saveTest() async {
    if (scheduledDate == null || scheduledTime == null || questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Please fill all details and add questions")));
      return;
    }

    final DateTime finalDateTime = DateTime(
      scheduledDate!.year, scheduledDate!.month, scheduledDate!.day,
      scheduledTime!.hour, scheduledTime!.minute
    );

    final newTest = TestModel(
      id: '', // Firestore auto-id dega
      subject: subject,
      topic: topic,
      scheduledAt: finalDateTime,
      questions: questions,
    );

    await FirebaseFirestore.instance.collection('tests').add(newTest.toMap());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Create Test (Admin)")),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(decoration: InputDecoration(labelText: "Subject"), onChanged: (v) => subject = v),
            TextField(decoration: InputDecoration(labelText: "Topic"), onChanged: (v) => topic = v),
            ListTile(
              title: Text(scheduledDate == null ? "Select Schedule" : "$scheduledDate $scheduledTime"),
              trailing: Icon(Icons.calendar_today),
              onTap: _pickDateTime,
            ),
            Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: questions.length,
                itemBuilder: (ctx, i) => ListTile(
                  title: Text("Q${i+1}: ${questions[i].questionText}"),
                  subtitle: Text("Ans: ${questions[i].correctOption}"),
                  trailing: IconButton(icon: Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => questions.removeAt(i))),
                ),
              ),
            ),
            ElevatedButton(onPressed: _addQuestionDialog, child: Text("Add Question")),
            SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: _saveTest, 
              child: Text("Save & Publish Test")
            ),
          ],
        ),
      ),
    );
  }
}
