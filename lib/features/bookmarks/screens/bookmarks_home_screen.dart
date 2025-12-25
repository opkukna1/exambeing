import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// ✅ IMPORTS
import 'package:exambeing/features/admin/screens/create_week_schedule.dart';
import 'package:exambeing/features/study_plan/screens/linked_notes_screen.dart';
import 'package:exambeing/features/study_plan/screens/study_results_screen.dart';
import 'package:exambeing/features/admin/screens/create_test_screen.dart';
import 'package:exambeing/features/study_plan/screens/attempt_test_screen.dart';
import 'package:exambeing/features/admin/screens/edit_week_schedule.dart';
import 'package:exambeing/features/study_plan/screens/test_list_screen.dart';
import 'package:exambeing/features/admin/screens/manage_students_screen.dart';

class BookmarksHomeScreen extends StatefulWidget {
  // 🔥 UPDATED: Added parameters to handle navigation from Store
  final String? examId;
  final String? examName;
  final bool isPremiumAccess; // true = Purchased, false = Demo/Locked

  const BookmarksHomeScreen({
    super.key,
    this.examId,
    this.examName,
    this.isPremiumAccess = true // Default true for normal usage
  });

  @override
  State<BookmarksHomeScreen> createState() => _BookmarksHomeScreenState();
}

class _BookmarksHomeScreenState extends State<BookmarksHomeScreen> {
  // 🔒 ADMIN CHECK
  final String adminEmail = "opsiddh42@gmail.com";
  
  // Safe Admin Check
  bool get isAdmin {
    final user = FirebaseAuth.instance.currentUser;
    return user != null && user.email?.toLowerCase().trim() == adminEmail.toLowerCase().trim();
  }

  String? selectedExamId;
  String? selectedExamName;
  
  // Week Selection State
  String? selectedWeekId;
  Map<String, dynamic>? selectedWeekData;

  @override
  void initState() {
    super.initState();
    // 🔥 AUTO-SELECT: Agar Store se aaye hain to Exam select kar lo
    if (widget.examId != null) {
      selectedExamId = widget.examId;
      selectedExamName = widget.examName;
    }
  }

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
                  'purchasedUsers': [], 
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
    Navigator.push(
      context, 
      MaterialPageRoute(builder: (c) => CreateWeekSchedule(examId: examId))
    );
  }

  // 3️⃣ Show Schedule Dialog (User View)
  void _showScheduleDialog(List<dynamic> topics, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Schedule: $title"),
        content: SizedBox(
          width: double.maxFinite,
          child: topics.isEmpty 
          ? const Padding(padding: EdgeInsets.all(10), child: Text("No detailed schedule yet."))
          : ListView.builder(
            shrinkWrap: true,
            itemCount: topics.length,
            itemBuilder: (c, i) => ListTile(
              leading: const Icon(Icons.check_circle_outline, color: Colors.deepPurple),
              title: Text(topics[i].toString()),
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    // Safety check for Login
    if (user == null || user.email == null) {
      return const Scaffold(body: Center(child: Text("Please Login to view your Plan")));
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Self Study Plan 🚀"),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          if (isAdmin) ...[
            // 👥 MANAGE STUDENTS BUTTON
            IconButton(
              icon: const Icon(Icons.people_alt, color: Colors.deepPurple),
              tooltip: "Manage Students",
              onPressed: () {
                Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (c) => const ManageStudentsScreen())
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.deepPurple),
              onPressed: _addNewExam,
              tooltip: "Add New Exam",
            )
          ]
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            // ------------------------------------------------
            // 1️⃣ SECTION: EXAM SELECTION (Horizontal)
            // ------------------------------------------------
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text("Choose Exam", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
            SizedBox(
              height: 60,
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('study_schedules').orderBy('createdAt', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  var exams = snapshot.data!.docs;

                  if (exams.isEmpty) return const Padding(padding: EdgeInsets.all(16), child: Text("No Exams Found"));

                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: exams.length,
                    itemBuilder: (context, index) {
                      var doc = exams[index];
                      var data = doc.data() as Map<String, dynamic>;
                      
                      // 🔥🔥 LOGIC: Check Permission (Dual Check + Demo Check)
                      return StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('study_schedules')
                            .doc(doc.id)
                            .collection('allowed_users')
                            .doc(user.email!.trim().toLowerCase())
                            .snapshots(),
                        builder: (context, permSnap) {
                          
                          bool isAllowed = false;
                          
                          // Rule 1: Admin sees everything
                          if (isAdmin) {
                            isAllowed = true;
                          } 
                          // Rule 2: Coming from Store Link (Demo Mode or Bought)
                          else if (widget.examId == doc.id) {
                            isAllowed = true;
                          }
                          // Rule 3: Check Subcollection (Primary Method)
                          else if (permSnap.hasData && permSnap.data!.exists) {
                            isAllowed = true; 
                          }
                          // Rule 4: Check Array (Backup Method)
                          else {
                             if (data.containsKey('purchasedUsers')) {
                               List users = List.from(data['purchasedUsers'] ?? []);
                               if (users.contains(user.email)) {
                                 isAllowed = true;
                               }
                             }
                          }

                          // ⛔ HIDE IF NOT ALLOWED
                          if (!isAllowed) return const SizedBox.shrink();

                          // ✅ SHOW CARD IF ALLOWED
                          bool isSelected = selectedExamId == doc.id;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedExamId = doc.id;
                                selectedExamName = data['examName'];
                                selectedWeekId = null; 
                                selectedWeekData = null;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.deepPurple : Colors.white,
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: isSelected ? Colors.deepPurple : Colors.grey.shade300),
                                boxShadow: isSelected ? [BoxShadow(color: Colors.deepPurple.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))] : [],
                              ),
                              child: Center(
                                child: Text(
                                  data['examName'] ?? "Exam",
                                  style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 10),

            // ------------------------------------------------
            // 2️⃣ SECTION: WEEK SELECTION (Horizontal)
            // ------------------------------------------------
            if (selectedExamId != null) ...[
               Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Choose Week", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    if(isAdmin)
                      InkWell(
                        onTap: () => _addWeekSchedule(selectedExamId!),
                        child: const Text("+ Add Week", style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
                      )
                  ],
                ),
              ),
              SizedBox(
                height: 100,
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('study_schedules')
                      .doc(selectedExamId)
                      .collection('weeks')
                      .orderBy('unlockTime')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox();
                    var weeks = snapshot.data!.docs;
                    
                    if (weeks.isEmpty) return const Center(child: Text("No schedule added yet."));

                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: weeks.length,
                      itemBuilder: (context, index) {
                        var weekDoc = weeks[index];
                        var data = weekDoc.data() as Map<String, dynamic>;
                        bool isSelected = selectedWeekId == weekDoc.id;
                        DateTime unlockDate = (data['unlockTime'] as Timestamp).toDate();
                        bool isLocked = DateTime.now().isBefore(unlockDate) && !isAdmin;

                        return GestureDetector(
                          onTap: isLocked ? null : () {
                            setState(() {
                              selectedWeekId = weekDoc.id;
                              selectedWeekData = data;
                            });
                          },
                          child: Container(
                            width: 140,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.blue.shade50 : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isSelected ? Colors.blue : Colors.grey.shade300, width: isSelected ? 2 : 1),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(isLocked ? Icons.lock : Icons.calendar_today, color: isLocked ? Colors.grey : Colors.blue),
                                const SizedBox(height: 5),
                                Text(data['weekTitle'], style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text(DateFormat('dd MMM').format(unlockDate), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],

            const Divider(height: 30),

            // ------------------------------------------------
            // 3️⃣ SECTION: MAIN 4 BUTTONS (Action Center)
            // ------------------------------------------------
            if (selectedWeekId != null && selectedWeekData != null) ...[
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text("Action Center: ${selectedWeekData!['weekTitle']}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.3,
                children: [
                  
                  // 🟡 Button 1: Schedule
                  _buildActionButton(
                    icon: Icons.list_alt, 
                    label: "Schedule", 
                    color: Colors.orange, 
                    onTap: () => _showScheduleDialog(selectedWeekData!['linkedTopics'] ?? [], selectedWeekData!['weekTitle'])
                  ),

                  // 🟢 Button 2: Notes
                  _buildActionButton(
                    icon: Icons.menu_book, 
                    label: "Notes", 
                    color: Colors.green, 
                    onTap: () {
                      List<dynamic> dataToSend = selectedWeekData != null && selectedWeekData!.containsKey('scheduleData')
                          ? selectedWeekData!['scheduleData']
                          : [];

                      Navigator.push(context, MaterialPageRoute(builder: (c) => LinkedNotesScreen(
                        weekTitle: selectedWeekData!['weekTitle'],
                        scheduleData: dataToSend
                      )));
                    }
                  ),

                  // 🟣 Button 3: Test
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('study_schedules').doc(selectedExamId)
                        .collection('weeks').doc(selectedWeekId)
                        .collection('tests')
                        .snapshots(),
                    builder: (context, testSnapshot) {
                      
                      String label = "Tests";
                      Color color = Colors.grey;
                      IconData icon = Icons.assignment;
                      int testCount = 0;

                      if (testSnapshot.hasData) {
                        testCount = testSnapshot.data!.docs.length;
                      }

                      if (testCount > 0) {
                        label = "$testCount Test(s)";
                        color = Colors.deepPurple;
                        icon = Icons.quiz;
                      } else {
                        label = "No Tests";
                        color = Colors.grey.shade400;
                        icon = Icons.do_not_disturb_on;
                      }

                      if (isAdmin) {
                        label = "Manage Tests";
                        color = Colors.redAccent;
                        icon = Icons.settings_suggest;
                      }

                      return _buildActionButton(
                        icon: icon, 
                        label: label, 
                        color: color, 
                        onTap: () {
                          // 🔥 PASSING THE LOCK STATUS DOWN
                          // Agar widget.isPremiumAccess FALSE hai, to Locked Mode ON hoga
                          // Agar user Admin hai, to Locked Mode OFF hoga
                          bool isLockedMode = !widget.isPremiumAccess && !isAdmin;

                          Navigator.push(
                            context, 
                            MaterialPageRoute(
                              builder: (c) => TestListScreen(
                                examId: selectedExamId!, 
                                weekId: selectedWeekId!,
                                isLockedMode: isLockedMode // 👈 Sending this to TestListScreen
                              )
                            )
                          );
                        }
                      );
                    },
                  ),

                  // 🔵 Button 4: Result
                  _buildActionButton(
                    icon: Icons.bar_chart, 
                    label: "Result", 
                    color: Colors.blue, 
                    onTap: () {
                       Navigator.push(context, MaterialPageRoute(builder: (c) => StudyResultsScreen(
                        examId: selectedExamId!,
                        examName: selectedExamName ?? "Exam"
                      )));
                    }
                  ),
                ],
              ),
              
              const SizedBox(height: 20),

              // ------------------------------------------------
              // 4️⃣ SECTION: ADMIN EXTRA CONTROLS
              // ------------------------------------------------
              if (isAdmin) ...[
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200)
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Admin Controls 🛡️", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _buildAdminButton(Icons.add_box, "Add Week", () => _addWeekSchedule(selectedExamId!)),
                          
                          _buildAdminButton(Icons.edit_document, "Edit Schedule", () {
                             Navigator.push(context, MaterialPageRoute(builder: (c) => EditWeekSchedule(
                               examId: selectedExamId!,
                               weekId: selectedWeekId!,
                               currentData: selectedWeekData!,
                             )));
                          }),

                          _buildAdminButton(Icons.add_task, "Add Test", () {
                             Navigator.push(context, MaterialPageRoute(builder: (c) => CreateTestScreen(
                              examId: selectedExamId!,
                              weekId: selectedWeekId!
                            )));
                          }),
                        ],
                      ),
                    ],
                  ),
                )
              ]

            ] else if (selectedExamId != null) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 50),
                  child: Text("👆 Select a Week above to see actions", style: TextStyle(color: Colors.grey)),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }

  // Helper Widget for Main User Buttons
  Widget _buildActionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 6, offset: const Offset(0, 4))],
          border: Border.all(color: Colors.grey.shade200)
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 10),
            Text(
              label, 
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)
            )
          ],
        ),
      ),
    );
  }

  // Helper Widget for Admin Buttons
  Widget _buildAdminButton(IconData icon, String label, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.red,
        elevation: 0,
        side: const BorderSide(color: Colors.red, width: 1)
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}
