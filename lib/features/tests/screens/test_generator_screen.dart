import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:exambeing/models/question_model.dart';
import 'package:exambeing/services/ad_manager.dart';

class TestGeneratorScreen extends StatefulWidget {
  const TestGeneratorScreen({super.key});

  @override
  State<TestGeneratorScreen> createState() => _TestGeneratorScreenState();
}

class _TestGeneratorScreenState extends State<TestGeneratorScreen> {
  String? selectedSubjectId;
  List<String> selectedTopicIds = [];
  double numberOfQuestions = 20; 
  bool _isLoading = false;

  // 1. Subjects Fetch karna
  Stream<QuerySnapshot> _getSubjects() {
    // Yahan hum 'subjects' collection se data la rahe hain
    return FirebaseFirestore.instance.collection('subjects').snapshots();
  }

  // 2. Topics Fetch karna (Subject ID ke basis par)
  Stream<QuerySnapshot> _getTopics(String subjectId) {
    return FirebaseFirestore.instance
        .collection('topics')
        .where('subjectId', isEqualTo: subjectId) 
        .snapshots();
  }

  Future<void> _generateTest() async {
    if (selectedTopicIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one topic!")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      List<String> allQuestionIds = [];

      // Har selected Topic ke liye questions dhundho
      for (String topicId in selectedTopicIds) {
         final query = await FirebaseFirestore.instance
             .collection('questions')
             .where('topicId', isEqualTo: topicId) // Logic ID se chalega
             .get();
         
         for (var doc in query.docs) {
           allQuestionIds.add(doc.id);
         }
      }

      if (allQuestionIds.isEmpty) {
        throw "No questions found for these topics.";
      }

      // Shuffle Logic (Taash ke patton ki tarah fenta)
      allQuestionIds.shuffle(Random());

      // Limit Questions
      int targetCount = numberOfQuestions.toInt();
      if (allQuestionIds.length < targetCount) {
        targetCount = allQuestionIds.length;
      }
      List<String> finalIds = allQuestionIds.sublist(0, targetCount);

      // Fetch Full Data
      List<Question> questions = [];
      await Future.wait(finalIds.map((id) async {
        final doc = await FirebaseFirestore.instance.collection('questions').doc(id).get();
        if (doc.exists) {
          questions.add(Question.fromFirestore(doc));
        }
      }));

      if (mounted) {
        setState(() => _isLoading = false);
        
        AdManager.showInterstitialAd(() {
          if (mounted) {
            context.push('/practice-mcq', extra: {
              'questions': questions,
              'topicName': 'Custom Challenge',
              'mode': 'test', 
            });
          }
        });
      }

    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Your Test 🎨")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- SUBJECT DROPDOWN ---
            const Text("Step 1: Select Subject", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: _getSubjects(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const LinearProgressIndicator();
                
                // Yahan hum data map kar rahe hain
                List<DropdownMenuItem<String>> items = snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  
                  // ✅ YAHAN CHANGE KIYA: 'subjectName' dikhana hai
                  // Fallback: Agar subjectName nahi mila to 'name' ya ID dikha do
                  String displayName = data['subjectName'] ?? data['name'] ?? 'Unknown Subject';

                  return DropdownMenuItem(
                    value: doc.id, // Value ID hi rahegi (Logic ke liye)
                    child: Text(displayName), // Dikhega Name (User ke liye)
                  );
                }).toList();

                return DropdownButtonFormField<String>(
                  value: selectedSubjectId,
                  items: items,
                  hint: const Text("Choose Subject"),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (val) {
                    setState(() {
                      selectedSubjectId = val;
                      selectedTopicIds.clear(); 
                    });
                  },
                );
              },
            ),
            
            const SizedBox(height: 24),
            
            // --- TOPICS SELECTION ---
            if (selectedSubjectId != null) ...[
              const Text("Step 2: Select Topics (Multi-select)", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _getTopics(selectedSubjectId!),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      
                      final topics = snapshot.data!.docs;
                      if (topics.isEmpty) return const Center(child: Text("No topics found"));

                      return ListView.builder(
                        itemCount: topics.length,
                        itemBuilder: (context, index) {
                          final doc = topics[index];
                          final data = doc.data() as Map<String, dynamic>;

                          // ✅ YAHAN CHANGE KIYA: 'topicName' dikhana hai
                          String displayTopic = data['topicName'] ?? data['name'] ?? 'Topic';
                          
                          final isSelected = selectedTopicIds.contains(doc.id); // ID check karo

                          return CheckboxListTile(
                            title: Text(displayTopic), // Dikhega Name
                            value: isSelected,
                            activeColor: Colors.deepPurple,
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  selectedTopicIds.add(doc.id); // Save ID hoga
                                } else {
                                  selectedTopicIds.remove(doc.id);
                                }
                              });
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 24),
            
            // --- SLIDER ---
            Text("Step 3: Number of Questions: ${numberOfQuestions.toInt()}", style: const TextStyle(fontWeight: FontWeight.bold)),
            Slider(
              value: numberOfQuestions,
              min: 10, max: 100, divisions: 9,
              label: numberOfQuestions.round().toString(),
              activeColor: Colors.deepPurple,
              onChanged: (double value) => setState(() => numberOfQuestions = value),
            ),
            
            const SizedBox(height: 24),
            
            // --- BUTTON ---
            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: _isLoading ? null : _generateTest,
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("GENERATE TEST 🚀", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
