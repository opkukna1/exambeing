import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:exambeing/models/question_model.dart';
import 'package:exambeing/services/ad_manager.dart'; // Ads zaroori hain

class TestGeneratorScreen extends StatefulWidget {
  const TestGeneratorScreen({super.key});

  @override
  State<TestGeneratorScreen> createState() => _TestGeneratorScreenState();
}

class _TestGeneratorScreenState extends State<TestGeneratorScreen> {
  // Selections
  String? selectedSubjectId;
  List<String> selectedTopicIds = [];
  double numberOfQuestions = 20; // Default slider value
  bool _isLoading = false;

  // Data fetching helper
  Stream<QuerySnapshot> _getSubjects() {
    return FirebaseFirestore.instance.collection('subjects').snapshots();
  }

  Stream<QuerySnapshot> _getTopics(String subjectId) {
    return FirebaseFirestore.instance
        .collection('topics')
        .where('subjectId', '==', subjectId)
        .snapshots();
  }

  // 🔥 MAGIC FUNCTION: Test Generate Karna
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

      // 1. Sare selected topics ke question IDs Lao
      // Note: Firestore 'in' query limit is 10. Agar topic > 10 hai to loop lagana padega.
      // Abhi hum maan ke chal rahe hain user 10 se kam topic select karega.
      
      // Optimization: Hum chunks mein query karenge agar topics jyada hain
      for (String topicId in selectedTopicIds) {
         final query = await FirebaseFirestore.instance
             .collection('questions') // Yahan wo 15k wala collection name ayega
             .where('topicId', '==', topicId)
             .get();
         
         for (var doc in query.docs) {
           allQuestionIds.add(doc.id);
         }
      }

      if (allQuestionIds.isEmpty) {
        throw "No questions found for these topics.";
      }

      // 2. Shuffle (Fentna)
      allQuestionIds.shuffle(Random());

      // 3. Cut List (Jitne user ne mange utne hi lo)
      int targetCount = numberOfQuestions.toInt();
      if (allQuestionIds.length < targetCount) {
        targetCount = allQuestionIds.length; // Agar total sawal hi kam hain
      }
      List<String> finalIds = allQuestionIds.sublist(0, targetCount);

      // 4. Fetch Full Data for selected IDs
      // (Future.wait se parallel download hoga - Fast)
      List<Question> questions = [];
      await Future.wait(finalIds.map((id) async {
        final doc = await FirebaseFirestore.instance.collection('questions').doc(id).get();
        if (doc.exists) {
          questions.add(Question.fromFirestore(doc));
        }
      }));

      // 5. Navigate to Practice Screen
      if (mounted) {
        setState(() => _isLoading = false);
        
        // Show Ad before starting
        AdManager.showInterstitialAd(() {
          context.push('/practice-mcq', extra: {
            'questions': questions,
            'topicName': 'Custom Challenge',
            'mode': 'test', // Test mode taki timer chale
          });
        });
      }

    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
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
            // 1. SUBJECT DROPDOWN
            const Text("Step 1: Select Subject", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: _getSubjects(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const LinearProgressIndicator();
                
                List<DropdownMenuItem<String>> items = snapshot.data!.docs.map((doc) {
                  return DropdownMenuItem(
                    value: doc.id,
                    child: Text(doc['name'] ?? 'Unknown'), // Field name check karlena
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
                      selectedTopicIds.clear(); // Subject badla to topics clear karo
                    });
                  },
                );
              },
            ),

            const SizedBox(height: 24),

            // 2. TOPICS MULTI-SELECT
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
                          final topicName = doc['name'] ?? 'Topic';
                          final isSelected = selectedTopicIds.contains(doc.id);

                          return CheckboxListTile(
                            title: Text(topicName),
                            value: isSelected,
                            activeColor: Colors.deepPurple,
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  selectedTopicIds.add(doc.id);
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

            // 3. SLIDER for Questions
            Text("Step 3: Number of Questions: ${numberOfQuestions.toInt()}", style: const TextStyle(fontWeight: FontWeight.bold)),
            Slider(
              value: numberOfQuestions,
              min: 10,
              max: 100,
              divisions: 9,
              label: numberOfQuestions.round().toString(),
              activeColor: Colors.deepPurple,
              onChanged: (double value) {
                setState(() {
                  numberOfQuestions = value;
                });
              },
            ),

            const SizedBox(height: 24),

            // 4. GENERATE BUTTON
            SizedBox(
              width: double.infinity,
              height: 55,
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
