import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// ✅ NEW IMPORTS (Make sure these files exist as per previous steps)
import 'package:exambeing/features/admin/screens/create_week_schedule.dart';
import 'package:exambeing/features/study_plan/screens/linked_notes_screen.dart';
// import 'package:exambeing/features/test/screens/test_screen.dart'; // Uncomment when test screen is ready

class BookmarksHomeScreen extends StatefulWidget {
  const BookmarksHomeScreen({super.key});

  @override
  State<BookmarksHomeScreen> createState() => _BookmarksHomeScreenState();
}

class _BookmarksHomeScreenState extends State<BookmarksHomeScreen> {
  // 🔒 ADMIN CHECK
  final String adminEmail = "opsiddh42@gmail.com";
  bool get isAdmin => FirebaseAuth.instance.currentUser?.email == adminEmail;

  String? selectedExamId;
  String? selectedExamName;

  // 1️⃣ ADMIN: Create New Exam
  void _addNewExam() {
    TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("New Exam Goal 🎯"),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: "Ex: RAS 2025, NEET Target"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await FirebaseFirestore.instance.collection('study_schedules').add({
                  'examName': nameController.text.trim(),
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (mounted) Navigator.pop(ctx);
              }
            },
            child: const Text("CREATE"),
          )
        ],
      ),
    );
  }

  // 2️⃣ ADMIN: Add Week Schedule (UPDATED LOGIC)
  void _addWeekSchedule(String examId) {
    // ✅ Ab ye Dialog nahi, balki Topic Selection wali nayi screen kholega
    Navigator.push(
      context, 
      MaterialPageRoute(builder: (c) => CreateWeekSchedule(examId: examId))
    );
  }

  // 3️⃣ DELETE EXAM (Admin Only)
  void _deleteExam(String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Exam?"),
        content: const Text("Is exam ka sara schedule delete ho jayega."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('study_schedules').doc(docId).delete();
              if (mounted) {
                 Navigator.pop(ctx);
                 setState(() { selectedExamId = null; });
              }
            },
            child: const Text("DELETE", style: TextStyle(color: Colors.red)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Self Study Plan 🚀"),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.deepPurple),
              onPressed: _addNewExam,
              tooltip: "Add New Exam",
            )
        ],
      ),
      body: Column(
        children: [
          // 🔽 SECTION 1: EXAM SELECTION (Horizontal List)
          SizedBox(
            height: 140,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('study_schedules').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                var exams = snapshot.data!.docs;

                if (exams.isEmpty) {
                  return Center(
                    child: isAdmin 
                    ? const Text("Tap + to add Exam") 
                    : const Text("No active exams found."),
                  );
                }

                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(16),
                  itemCount: exams.length,
                  itemBuilder: (context, index) {
                    var doc = exams[index];
                    bool isSelected = selectedExamId == doc.id;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedExamId = doc.id;
                          selectedExamName = doc['examName'];
                        });
                      },
                      child: Container(
                        width: 120,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.deepPurple : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isSelected ? Colors.deepPurple : Colors.grey.shade300),
                          boxShadow: [
                             if(isSelected) BoxShadow(color: Colors.deepPurple.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
                          ]
                        ),
                        child: Stack(
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.emoji_events, size: 30, color: isSelected ? Colors.white : Colors.orange),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                  child: Text(
                                    doc['examName'],
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.white : Colors.black87
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            // Admin Delete Button (Small x)
                            if (isAdmin)
                              Positioned(
                                top: 0, right: 0,
                                child: InkWell(
                                  onTap: () => _deleteExam(doc.id),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                    child: const Icon(Icons.close, size: 10, color: Colors.white),
                                  ),
                                ),
                              )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          const Divider(height: 1),

          // 🔽 SECTION 2: WEEKS SCHEDULE LIST
          Expanded(
            child: selectedExamId == null
                ? const Center(child: Text("👈 Select an Exam to view Schedule"))
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('study_schedules')
                        .doc(selectedExamId)
                        .collection('weeks')
                        .orderBy('unlockTime')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      var weeks = snapshot.data!.docs;

                      return Column(
                        children: [
                          // Header for selected exam
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Schedule for $selectedExamName", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                if (isAdmin)
                                  ElevatedButton.icon(
                                    onPressed: () => _addWeekSchedule(selectedExamId!),
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text("Add Week"),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                                  )
                              ],
                            ),
                          ),
                          
                          // List of Weeks
                          Expanded(
                            child: weeks.isEmpty
                                ? const Center(child: Text("No schedule added yet."))
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    itemCount: weeks.length,
                                    itemBuilder: (context, index) {
                                      var weekDoc = weeks[index];
                                      var data = weekDoc.data() as Map<String, dynamic>;
                                      DateTime unlockDate = (data['unlockTime'] as Timestamp).toDate();
                                      bool isLocked = DateTime.now().isBefore(unlockDate);
                                      
                                      // Topics List fetch kar rahe hain
                                      List<dynamic> topics = data['linkedTopics'] ?? [];

                                      return Card(
                                        margin: const EdgeInsets.only(bottom: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(data['weekTitle'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                                  if(isAdmin)
                                                    InkWell(
                                                      onTap: () => FirebaseFirestore.instance.collection('study_schedules').doc(selectedExamId).collection('weeks').doc(weekDoc.id).delete(),
                                                      child: const Icon(Icons.delete, color: Colors.grey, size: 20),
                                                    )
                                                ],
                                              ),
                                              Text("Test Unlocks: ${DateFormat('dd MMM').format(unlockDate)}", style: const TextStyle(color: Colors.grey)),
                                              
                                              const SizedBox(height: 15),
                                              
                                              // ACTION BUTTONS
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: OutlinedButton.icon(
                                                      onPressed: () {
                                                        // ✅ OPEN LINKED NOTES SCREEN
                                                        Navigator.push(context, MaterialPageRoute(builder: (c) => LinkedNotesScreen(
                                                          weekTitle: data['weekTitle'],
                                                          linkedTopics: topics
                                                        )));
                                                      },
                                                      icon: const Icon(Icons.menu_book, color: Colors.green),
                                                      label: const Text("Read Notes"),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: ElevatedButton.icon(
                                                      onPressed: isLocked && !isAdmin 
                                                        ? null 
                                                        : () {
                                                          // ✅ START TEST LOGIC (Topic list pass kar rahe hain)
                                                          // Yahan aap apna Test Screen push karein:
                                                          // Navigator.push(context, MaterialPageRoute(builder: (c) => DynamicTestScreen(topics: topics)));
                                                          
                                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Starting Test covering: ${topics.join(", ")}")));
                                                        },
                                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                                                      icon: Icon(isLocked ? Icons.lock : Icons.play_arrow),
                                                      label: Text(isLocked ? "Locked" : "Start Test"),
                                                    ),
                                                  ),
                                                ],
                                              )
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
