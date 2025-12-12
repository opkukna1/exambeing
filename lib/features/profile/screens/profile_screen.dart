import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:exambeing/services/revision_db.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? user = FirebaseAuth.instance.currentUser;

  Stream<DocumentSnapshot<Map<String, dynamic>>> _getUserStatsStream() {
    if (user == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () {
              context.push('/settings');
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _getUserStatsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = snapshot.data?.data();
          final stats = userData?['stats'] as Map<String, dynamic>? ?? {};

          int totalTests = stats['totalTests'] ?? 0;
          int totalQuestions = stats['totalQuestions'] ?? 0;
          int correct = stats['correct'] ?? 0;
          int wrong = stats['wrong'] ?? 0;
          
          double accuracy = totalQuestions == 0 ? 0 : (correct / totalQuestions) * 100;

          Map<String, dynamic> subjectPerformance = stats['subjects'] ?? {};
          String strongSubject = "Not enough data";
          String weakSubject = "Not enough data";
          double highestAcc = -1;
          double lowestAcc = 101;

          subjectPerformance.forEach((subject, data) {
            int subTotal = data['total'] ?? 0;
            int subCorrect = data['correct'] ?? 0;
            if (subTotal > 5) { 
              double acc = (subCorrect / subTotal) * 100;
              if (acc > highestAcc) {
                highestAcc = acc;
                strongSubject = subject;
              }
              if (acc < lowestAcc) {
                lowestAcc = acc;
                weakSubject = subject;
              }
            }
          });

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              if (user != null) _buildUserCard(),

              const SizedBox(height: 24),
              Text("Performance Overview", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 1.6,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _buildStatCard("Tests Taken", "$totalTests", Colors.blue),
                  _buildStatCard("Accuracy", "${accuracy.toStringAsFixed(1)}%", Colors.purple),
                  _buildStatCard("Right Ans", "$correct", Colors.green),
                  _buildStatCard("Wrong Ans", "$wrong", Colors.red),
                ],
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(child: _buildSubjectCard("Strong Subject", strongSubject, Colors.green.shade50, Colors.green.shade800)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        if (subjectPerformance.isNotEmpty) {
                          _showWeakTopicsDialog(subjectPerformance);
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: _buildSubjectCard("Weak Subject", weakSubject, Colors.red.shade50, Colors.red.shade800, isClickable: true),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),
              _buildRevisionBox(context),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUserCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
              child: user?.photoURL == null
                  ? Text(user?.displayName?.substring(0, 1).toUpperCase() ?? 'U', style: const TextStyle(fontSize: 24))
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user?.displayName ?? 'No Name', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  if (user?.email != null) Text(user!.email!, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
        ],
      ),
    );
  }

  Widget _buildSubjectCard(String title, String subject, Color bgColor, Color textColor, {bool isClickable = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: isClickable ? Border.all(color: textColor.withOpacity(0.3)) : null,
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            subject, 
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15), 
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (isClickable)
             Padding(
               padding: const EdgeInsets.only(top: 4.0),
               child: Icon(Icons.touch_app, size: 14, color: textColor.withOpacity(0.6)),
             ),
        ],
      ),
    );
  }

  Widget _buildRevisionBox(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade50, Colors.orange.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.shade300),
        boxShadow: [
          BoxShadow(color: Colors.orange.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))
        ]
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 28),
              const SizedBox(width: 10),
              Text(
                "Mistake Revision Zone", 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange.shade900)
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Re-attempt questions you got wrong. Questions are removed after 2 correct attempts.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.orange.shade900.withOpacity(0.7), fontSize: 13),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade800,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: () => _startRevisionTest(context),
              child: const Text("Start Revision Set (25 Q)", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _showWeakTopicsDialog(Map<String, dynamic> performance) {
    List<MapEntry<String, dynamic>> weakTopics = performance.entries
        .where((e) => (e.value['total'] > 0) && ((e.value['correct'] / e.value['total']) < 0.5))
        .toList();

    showModalBottomSheet(
      context: context,
      // ✅ FIX: verticalTop galat tha, borderRadius.vertical sahi hai
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.trending_down, color: Colors.red),
                  const SizedBox(width: 10),
                  const Text("Areas for Improvement", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const Divider(),
              if (weakTopics.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text("No specific weak areas found yet! Keep it up! 🎉"),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: weakTopics.length,
                    itemBuilder: (context, index) {
                      final topic = weakTopics[index];
                      int total = topic.value['total'];
                      int correct = topic.value['correct'];
                      double acc = (correct / total) * 100;
                      return ListTile(
                        title: Text(topic.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                          child: Text("${acc.toStringAsFixed(0)}% Acc", style: TextStyle(color: Colors.red.shade800, fontSize: 12)),
                        ),
                        subtitle: Text("Correct: $correct / $total"),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _startRevisionTest(BuildContext context) async {
    List<Map<String, dynamic>> rawData = await RevisionDB.instance.getRevisionSet();
    
    if (!context.mounted) return;

    if (rawData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No wrong questions to revise! Great job! 🎉"),
          backgroundColor: Colors.green,
        )
      );
      return;
    }

    List<Map<String, dynamic>> questions = rawData.map((e) => e['parsedData'] as Map<String, dynamic>).toList();
    List<String> dbIds = rawData.map((e) => e['id'] as String).toList();

    context.push('/test-screen', extra: {
      'questions': questions, 
      'isRevision': true, 
      'dbIds': dbIds 
    });
  }
}
