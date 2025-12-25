// File Path: lib/features/study_plan/screens/series_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// 🔥 IMP: Yahan apni AttemptTestScreen wali file import karein
// Agar wo same folder mein hai to aise hi rehne dein, warna path adjust karein
import 'attempt_test_screen.dart'; 

class SeriesDetailScreen extends StatefulWidget {
  final String scheduleDocId; // Firestore Doc ID (Linked Schedule ID)
  final String title;

  const SeriesDetailScreen({
    super.key, 
    required this.scheduleDocId, 
    required this.title
  });

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  bool isOwned = false; // By default Locked maan ke chalenge

  @override
  void initState() {
    super.initState();
    _checkOwnership();
  }

  // 🔍 Check karein ki user ne ye Series khareedi hai ya nahi
  Future<void> _checkOwnership() async {
    if (user == null) return;
    try {
      var doc = await FirebaseFirestore.instance
          .collection('study_schedules')
          .doc(widget.scheduleDocId)
          .collection('allowed_users')
          .doc(user!.email)
          .get();

      // Agar user allowed_users list mein hai aur access true hai
      if (doc.exists && doc.data()?['access'] == true) {
        if (mounted) setState(() { isOwned = true; });
      }
    } catch (e) {
      debugPrint("Error checking ownership: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('study_schedules')
            .doc(widget.scheduleDocId)
            .snapshots(),
        builder: (context, snapshot) {
          // 1. Loading State
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          // 2. Error/Empty State
          if (!snapshot.data!.exists) {
            return const Center(
              child: Text("Schedule not uploaded yet.\nContact Admin.", textAlign: TextAlign.center),
            );
          }

          var data = snapshot.data!.data() as Map<String, dynamic>;
          List tests = data['tests'] ?? [];

          if (tests.isEmpty) return const Center(child: Text("No tests added to schedule."));

          // 3. List of Tests
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tests.length,
            itemBuilder: (context, index) {
              var test = tests[index];
              
              // 🔥 CORE LOGIC:
              // Index 0 (First Test) hamesha FREE rahega.
              // Baaki tests tabhi khulenge jab 'isOwned' true ho.
              bool isFree = (index == 0) || isOwned;

              // Date Formatting
              String dateStr = "Upcoming";
              if (test['date'] != null && test['date'] is Timestamp) {
                dateStr = DateFormat('dd MMM').format((test['date'] as Timestamp).toDate());
              }

              return Card(
                elevation: isFree ? 3 : 0,
                color: isFree ? Colors.white : Colors.grey.shade50,
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isFree 
                      ? const BorderSide(color: Colors.deepPurple, width: 1) 
                      : BorderSide.none,
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  // Left Side: Date Box
                  leading: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isFree ? Colors.deepPurple.shade50 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(dateStr.split(' ')[0], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        if (dateStr.split(' ').length > 1)
                          Text(dateStr.split(' ')[1], style: const TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                  
                  // Center: Test Name & Label
                  title: Row(
                    children: [
                      Text("Test ${index + 1}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(width: 8),
                      // Agar Test 1 hai aur user ne khareeda nahi hai, to "FREE DEMO" dikhao
                      if (index == 0 && !isOwned)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)),
                          child: const Text("FREE DEMO", style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                        )
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      test['topic'] ?? "Full Mock Test",
                      style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        fontSize: 16,
                        color: isFree ? Colors.black87 : Colors.grey
                      ),
                    ),
                  ),

                  // Right Side: Play / Lock Button
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFree ? Colors.deepPurple : Colors.grey.shade300,
                      foregroundColor: Colors.white,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(10),
                      elevation: isFree ? 2 : 0,
                    ),
                    onPressed: () {
                      if (isFree) {
                        // ✅ SUCCESS: Test Start karo
                        // Hum yahan unique ID bana rahe hain taaki result save ho sake
                        String uniqueTestId = "${widget.scheduleDocId}_test_$index";
                        
                        Navigator.push(
                          context, 
                          MaterialPageRoute(
                            builder: (context) => AttemptTestScreen(
                              testId: uniqueTestId,
                              examId: widget.scheduleDocId,
                              testData: test, // Pura data pass kar diya
                            )
                          )
                        );
                      } else {
                        // 🔒 LOCKED
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("🔒 Locked! Please Buy the Series to unlock."),
                            duration: Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          )
                        );
                      }
                    },
                    child: Icon(isFree ? Icons.play_arrow_rounded : Icons.lock_outline_rounded),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
