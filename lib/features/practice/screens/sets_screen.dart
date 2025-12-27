import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Admin Check
import 'package:cloud_firestore/cloud_firestore.dart'; // Database Save
import '../../../models/question_model.dart';
import '../../../services/firebase_data_service.dart';

// ✅ 1. AdManager Import
import 'package:exambeing/services/ad_manager.dart';

class SetsScreen extends StatefulWidget {
  final Map<String, String> topicData;
  const SetsScreen({super.key, required this.topicData});

  @override
  State<SetsScreen> createState() => _SetsScreenState();
}

class _SetsScreenState extends State<SetsScreen> {
  final FirebaseDataService dataService = FirebaseDataService();
  late Future<List<Question>> _questionsFuture;

  late String topicId;
  late String topicName;
  final int setSize = 25;

  // 🔥 Admin Check Variable
  bool isAdmin = false;

  @override
  void initState() {
    super.initState();
    topicId = widget.topicData['topicId']!;
    topicName = widget.topicData['topicName']!;
    _questionsFuture = dataService.getQuestions(topicId);
    
    // ✅ Performance Optimized Admin Check
    // FirebaseAuth.currentUser is synchronous (instant), so it won't slow down the app.
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email == "opsiddh42@gmail.com") {
      isAdmin = true;
    }

    // Pre-load Ad
    AdManager.loadInterstitialAd();
  }

  // 🔥 Refresh List after adding question
  void _refreshList() {
    setState(() {
      _questionsFuture = dataService.getQuestions(topicId);
    });
  }
  
  void _showModeSelectionDialog(List<Question> questionSet) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Choose Your Mode'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.edit_note, color: Theme.of(context).colorScheme.primary),
                title: const Text('Practice Mode', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Get instant feedback & explanations.'),
                onTap: () {
                  Navigator.pop(dialogContext);
                  context.push(
                    '/practice-mcq',
                    extra: {
                      'questions': questionSet,
                      'topicName': topicName,
                      'mode': 'practice',
                    },
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.timer_outlined, color: Theme.of(context).colorScheme.secondary),
                title: const Text('Test Mode', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Simulate a real exam with a timer.'),
                onTap: () {
                  Navigator.pop(dialogContext);
                  context.push(
                    '/practice-mcq',
                    extra: {
                      'questions': questionSet,
                      'topicName': topicName,
                      'mode': 'test',
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(topicName),
      ),
      // 🔥🔥 PLUS BUTTON (SIRF ADMIN KO DIKHEGA) 🔥🔥
      floatingActionButton: isAdmin 
        ? FloatingActionButton(
            backgroundColor: Colors.deepPurple,
            child: const Icon(Icons.add, color: Colors.white),
            onPressed: () {
              // Open Add Question Screen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AdminAddQuestionScreen(
                    topicId: topicId,
                    topicName: topicName,
                  ),
                ),
              ).then((_) => _refreshList()); // Wapas aane par list refresh karo
            },
          )
        : null,
      body: FutureBuilder<List<Question>>(
        future: _questionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No questions found for this topic.'));
          }

          final allQuestions = snapshot.data!;
          final numberOfSets = (allQuestions.length / setSize).ceil();

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
            itemCount: numberOfSets,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final setIndex = index + 1;
              final questionSet = allQuestions.sublist(
                index * setSize,
                (index * setSize + setSize > allQuestions.length)
                    ? allQuestions.length
                    : index * setSize + setSize,
              );

              return _buildSetCard(context, setIndex, questionSet);
            },
          );
        },
      ),
    );
  }

  Widget _buildSetCard(BuildContext context, int setIndex, List<Question> questionSet) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            '$setIndex',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        title: Text(
          'Set $setIndex',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${questionSet.length} Questions'),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
        
        onTap: () {
          AdManager.showInterstitialAd(() {
            if (mounted) {
               _showModeSelectionDialog(questionSet);
            }
          });
        },
      ),
    );
  }
}

// 🔥🔥🔥 NEW SCREEN: ADMIN ADD QUESTION 🔥🔥🔥
class AdminAddQuestionScreen extends StatefulWidget {
  final String topicId;
  final String topicName;

  const AdminAddQuestionScreen({super.key, required this.topicId, required this.topicName});

  @override
  State<AdminAddQuestionScreen> createState() => _AdminAddQuestionScreenState();
}

class _AdminAddQuestionScreenState extends State<AdminAddQuestionScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers for Input Fields
  final TextEditingController _qTextController = TextEditingController();
  final TextEditingController _optAController = TextEditingController();
  final TextEditingController _optBController = TextEditingController();
  final TextEditingController _optCController = TextEditingController();
  final TextEditingController _optDController = TextEditingController();
  final TextEditingController _expController = TextEditingController();

  int _correctIndex = 0; // Default Correct Answer = Option A (Index 0)
  bool _isSaving = false;

  // 🔥 Save Logic Matches Your Database Structure
  Future<void> _saveToFirebase() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // Data Structure based on typical Question Model
      Map<String, dynamic> questionData = {
        'topicId': widget.topicId,
        'questionText': _qTextController.text.trim(), // camelCase
        'options': [
          _optAController.text.trim(),
          _optBController.text.trim(),
          _optCController.text.trim(),
          _optDController.text.trim(),
        ],
        'correctAnswerIndex': _correctIndex, // camelCase as per standard model
        'explanation': _expController.text.trim(), // camelCase
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Saving to 'questions' collection
      await FirebaseFirestore.instance.collection('questions').add(questionData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Question Added Successfully! ✅"), backgroundColor: Colors.green),
        );
        // Clear Form for next entry
        _qTextController.clear();
        _optAController.clear();
        _optBController.clear();
        _optCController.clear();
        _optDController.clear();
        _expController.clear();
        setState(() {
          _correctIndex = 0;
          _isSaving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Question 📝")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Topic: ${widget.topicName}", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              
              // Question Input
              TextFormField(
                controller: _qTextController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: "Question Text", border: OutlineInputBorder(), alignLabelWithHint: true),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 20),

              const Text("Options & Correct Answer:", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              // Option A
              _buildOptionRow(0, "Option A", _optAController),
              // Option B
              _buildOptionRow(1, "Option B", _optBController),
              // Option C
              _buildOptionRow(2, "Option C", _optCController),
              // Option D
              _buildOptionRow(3, "Option D", _optDController),

              const SizedBox(height: 20),

              // Explanation Input
              TextFormField(
                controller: _expController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: "Explanation (Optional)", border: OutlineInputBorder()),
              ),

              const SizedBox(height: 30),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveToFirebase,
                  icon: _isSaving 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                      : const Icon(Icons.save),
                  label: const Text("SAVE QUESTION", style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper Widget for Options with Radio Button
  Widget _buildOptionRow(int index, String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Radio<int>(
            value: index,
            groupValue: _correctIndex,
            activeColor: Colors.green,
            onChanged: (val) => setState(() => _correctIndex = val!),
          ),
          Expanded(
            child: TextFormField(
              controller: controller,
              decoration: InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: _correctIndex == index ? const Icon(Icons.check_circle, color: Colors.green) : null
              ),
              validator: (v) => v!.isEmpty ? "Required" : null,
            ),
          ),
        ],
      ),
    );
  }
}
