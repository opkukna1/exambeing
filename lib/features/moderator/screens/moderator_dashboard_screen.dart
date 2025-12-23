import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ModeratorDashboardScreen extends StatelessWidget {
  const ModeratorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final String myEmail = user?.email?.trim().toLowerCase() ?? "";

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Earning Dashboard 💰"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 🔥 SIRF MERA DATA LAO
        stream: FirebaseFirestore.instance
            .collection('moderator_assignments')
            .where('moderatorEmail', isEqualTo: myEmail)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.gpp_bad, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 10),
                  const Text("You are not assigned as a Moderator.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          // Moderator ke pass multiple schedules ho sakte hain
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              
              String scheduleId = data['scheduleId'] ?? '';
              String title = data['scheduleTitle'] ?? 'Unknown Exam';
              int commission = data['commissionPrice'] ?? 0;
              int totalWithdrawn = data['totalWithdrawn'] ?? 0;
              List history = data['withdrawalHistory'] ?? [];

              // 🔥 FETCH REAL-TIME SALES
              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('study_schedules').doc(scheduleId).snapshots(),
                builder: (context, scheduleSnap) {
                  
                  int studentCount = 0;
                  if (scheduleSnap.hasData && scheduleSnap.data!.exists) {
                    var sData = scheduleSnap.data!.data() as Map<String, dynamic>;
                    if (sData.containsKey('purchasedUsers')) {
                      studentCount = (sData['purchasedUsers'] as List).length;
                    }
                  }

                  // 💰 CALCULATIONS
                  int totalEarnings = studentCount * commission;
                  int availableBalance = totalEarnings - totalWithdrawn;

                  return Card(
                    elevation: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: Colors.deepPurple.withOpacity(0.1), shape: BoxShape.circle),
                                child: const Icon(Icons.school, color: Colors.deepPurple),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    Text("Commission: ₹$commission per student", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 30),

                          // Stats Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildStatItem("Students", "$studentCount", Colors.black),
                              _buildStatItem("Total Earned", "₹$totalEarnings", Colors.blue),
                              _buildStatItem("Paid Out", "₹$totalWithdrawn", Colors.red),
                            ],
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Big Balance
                          Container(
                            padding: const EdgeInsets.all(15),
                            width: double.infinity,
                            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green.shade200)),
                            child: Column(
                              children: [
                                const Text("Available for Withdrawal", style: TextStyle(color: Colors.green)),
                                const SizedBox(height: 5),
                                Text("₹$availableBalance", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),
                          const Text("Payment History", style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          
                          // History List (Last 3 only)
                          if (history.isEmpty) 
                            const Text("No withdrawals yet.", style: TextStyle(fontSize: 12, color: Colors.grey))
                          else 
                            ...history.reversed.take(3).map((h) {
                               DateTime date = DateTime.tryParse(h['date']) ?? DateTime.now();
                               return Padding(
                                 padding: const EdgeInsets.only(bottom: 5),
                                 child: Row(
                                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                   children: [
                                     Text(DateFormat('dd MMM').format(date), style: const TextStyle(fontSize: 12)),
                                     Text("+ ₹${h['amount']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13)),
                                   ],
                                 ),
                               );
                            }).toList()
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
