import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// ✅ Agar apke project me Admin form alag file me hai to import karein, 
// Varna neeche maine _showAddWeekDialog function isi file me rakha hai simplicity ke liye.

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

  // 2️⃣ ADMIN: Add Week Schedule
  void _addWeekSchedule(String examId) {
    TextEditingController titleController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    // Topics selection logic complex ho sakta hai, abhi simple rakhte hain testing ke liye
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Add Week Schedule"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: "Week Title (e.g. Week 1: History)"),
                ),
                const SizedBox(height: 10),
                ListTile(
                  title: Text("Unlock: ${DateFormat('dd MMM').format(selectedDate)}"),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                ),
                const Text("Note: Topics selection agle update me lagayenge.", style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () async {
                  if (titleController.text.isNotEmpty) {
                    await FirebaseFirestore.instance
                        .collection('study_schedules')
                        .doc(examId)
                        .collection('weeks')
                        .add({
                      'weekTitle': titleController.text.trim(),
                      'unlockTime': Timestamp.fromDate(selectedDate),
                      'linkedTopics': [], // Abhi empty rakha hai
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                    if (mounted) Navigator.pop(ctx);
                  }
                },
                child: const Text("SAVE WEEK"),
              )
            ],
          );
        },
      ),
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
                                                        // TODO: Open Linked Notes Screen
                                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Opening Notes for this week...")));
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
                                                          // TODO: Start Test Logic
                                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Starting Test...")));
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
