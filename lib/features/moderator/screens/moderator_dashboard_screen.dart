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
      backgroundColor: Colors.grey[50], // Thoda light background achha lagta hai
      appBar: AppBar(
        title: const Text("My Earning Dashboard 💰"),
        backgroundColor: Colors.deepPurple, // Theme match karne ke liye
        foregroundColor: Colors.white,
        elevation: 1,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 🔥 SIRF MERA DATA LAO (Direct Moderator Assignment se)
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
                  const SizedBox(height: 5),
                  Text("Login: $myEmail", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              
              String title = data['scheduleTitle'] ?? 'Unknown Exam';
              int commission = data['commissionPrice'] ?? 0;
              
              // 🔥 CORE CHANGE: Data direct yahan se uthao (Admin Feeder wala data)
              // Ab hume 'study_schedules' mein jane ki zarurat nahi hai
              int studentCount = data['studentCount'] ?? 0; 
              int totalEarnings = data['totalEarnings'] ?? 0; 
              
              int totalWithdrawn = data['totalWithdrawn'] ?? 0;
              List history = data['withdrawalHistory'] ?? [];

              // Calculate Balance
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
                          _buildStatItem("Paid Out", "₹$totalWithdrawn", Colors.orange),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Big Balance Box
                      Container(
                        padding: const EdgeInsets.all(15),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1), // Light Green
                          borderRadius: BorderRadius.circular(10), 
                          border: Border.all(color: Colors.green.withOpacity(0.5))
                        ),
                        child: Column(
                          children: [
                            const Text("Available for Withdrawal", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 5),
                            Text("₹$availableBalance", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                      const Text("Payment History", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      
                      // History List (Last 5 only)
                      if (history.isEmpty) 
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Center(child: Text("No withdrawals yet.", style: TextStyle(fontSize: 12, color: Colors.grey))),
                        )
                      else 
                        ...history.reversed.take(5).map((h) {
                           DateTime date = DateTime.tryParse(h['date'].toString()) ?? DateTime.now();
                           return Container(
                             margin: const EdgeInsets.only(bottom: 8),
                             padding: const EdgeInsets.all(10),
                             decoration: BoxDecoration(
                               color: Colors.grey[50],
                               borderRadius: BorderRadius.circular(8),
                               border: Border.all(color: Colors.grey.shade200)
                             ),
                             child: Row(
                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
                               children: [
                                 Row(
                                   children: [
                                     const Icon(Icons.check_circle, size: 16, color: Colors.green),
                                     const SizedBox(width: 8),
                                     Text(DateFormat('dd MMM, hh:mm a').format(date), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                   ],
                                 ),
                                 Text("+ ₹${h['amount']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
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
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }
}
