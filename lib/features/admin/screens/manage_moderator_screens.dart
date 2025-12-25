import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ModeratorDashboardScreen extends StatelessWidget {
  const ModeratorDashboardScreen({super.key});

  // --- STUDENT LIST DIALOG ---
  void _showStudentListDialog(BuildContext context, List<QueryDocumentSnapshot> students, int commissionRate) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("My Students (${students.length}) 🎓"),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: students.isEmpty 
            ? const Center(child: Text("No students found after your joining date.")) 
            : ListView.builder(
                itemCount: students.length,
                itemBuilder: (context, index) {
                  var data = students[index].data() as Map<String, dynamic>;
                  String email = data['email'] ?? 'Unknown';
                  String name = data['displayName'] ?? email.split('@')[0];
                  Timestamp? grantedAt = data['grantedAt'];
                  
                  String dateStr = grantedAt != null 
                      ? DateFormat('dd MMM, hh:mm a').format(grantedAt.toDate())
                      : "Unknown";

                  return Card(
                    elevation: 0,
                    color: Colors.grey.shade50,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      dense: true,
                      leading: const CircleAvatar(backgroundColor: Colors.deepPurple, radius: 15, child: Icon(Icons.person, color: Colors.white, size: 16)),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text("Joined: $dateStr", style: const TextStyle(fontSize: 11)),
                      trailing: Text("+₹$commissionRate", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    ),
                  );
                },
              ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
      ),
    );
  }

  // --- HISTORY DIALOG ---
  void _showHistoryDialog(BuildContext context, List<dynamic> history) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Payout History 🏦"),
        content: SizedBox(
          width: double.maxFinite, height: 300,
          child: history.isEmpty ? const Center(child: Text("No payouts received yet.")) : ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, index) {
              var item = history[history.length - 1 - index];
              return ListTile(
                leading: const Icon(Icons.download_done, color: Colors.green),
                title: Text("Received: ₹${item['amount']}"),
                subtitle: Text(DateFormat('dd MMM yyyy').format(DateTime.parse(item['date']))),
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) return const Scaffold(body: Center(child: Text("Please Login")));

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Partner Dashboard 🚀"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 1. Moderator ka Assignment Document Dhoondho
        stream: FirebaseFirestore.instance
            .collection('moderator_assignments')
            .where('moderatorEmail', isEqualTo: user.email!.trim().toLowerCase())
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_off, size: 60, color: Colors.grey.shade400),
                    const SizedBox(height: 10),
                    const Text("No active partnership found.", style: TextStyle(fontWeight: FontWeight.bold)),
                    Text("Logged in as: ${user.email}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;

              // Data Extract
              String scheduleId = data['scheduleId'] ?? '';
              String examName = data['scheduleTitle'] ?? 'Exam';
              int commission = data['commissionPrice'] ?? 0;
              int totalWithdrawn = data['totalWithdrawn'] ?? 0;
              List history = data['withdrawalHistory'] ?? [];
              
              // 🔥 JOINING DATE (Filter Key)
              Timestamp modJoinedAt = data['createdAt'] ?? Timestamp.now(); 

              // 2. 🔥 INNER STREAM: Real-Time Student Calculation (Exact logic from Admin Panel)
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('study_schedules')
                    .doc(scheduleId)
                    .collection('allowed_users') // Sub-collection
                    .where('grantedAt', isGreaterThanOrEqualTo: modJoinedAt) // Date Filter
                    .snapshots(),
                builder: (context, studentSnap) {
                  
                  int studentCount = 0;
                  List<QueryDocumentSnapshot> studentDocs = [];

                  if (studentSnap.hasData) {
                    studentDocs = studentSnap.data!.docs;
                    studentCount = studentDocs.length;
                  }

                  // 💰 Calculations
                  int totalEarnings = studentCount * commission;
                  int pendingBalance = totalEarnings - totalWithdrawn;

                  return Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    margin: const EdgeInsets.only(bottom: 20),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // HEADER
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: Colors.deepPurple.shade50, borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.school, color: Colors.deepPurple),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(examName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    Text("Commission: ₹$commission / student", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 30),

                          // STATS GRID
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildStatItem("Students", "$studentCount", Colors.blue),
                              _buildStatItem("Total Earned", "₹$totalEarnings", Colors.deepPurple),
                              _buildStatItem("Received", "₹$totalWithdrawn", Colors.orange),
                            ],
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // BALANCE BOX
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
                            ),
                            child: Column(
                              children: [
                                const Text("Pending Payout", style: TextStyle(color: Colors.white70, fontSize: 12)),
                                const SizedBox(height: 5),
                                Text("₹$pendingBalance", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ACTION BUTTONS
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.people_outline),
                                  label: const Text("Students"),
                                  onPressed: () => _showStudentListDialog(context, studentDocs, commission),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                                  icon: const Icon(Icons.history),
                                  label: const Text("History"),
                                  onPressed: () => _showHistoryDialog(context, history),
                                ),
                              ),
                            ],
                          ),

                          // 🔥 DEBUG INFO (Only shows if 0 students found, to help you check)
                          if (studentCount == 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 15),
                              child: Text(
                                "Debug: Tracking Schedule ID: $scheduleId\nCounting students joined after: ${DateFormat('dd MMM yyyy').format(modJoinedAt.toDate())}",
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                                textAlign: TextAlign.center,
                              ),
                            )
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
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
