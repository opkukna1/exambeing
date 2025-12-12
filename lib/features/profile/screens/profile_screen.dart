import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:exambeing/services/revision_db.dart';
import 'package:exambeing/models/question_model.dart';
import 'package:exambeing/services/ad_manager.dart';
import 'package:exambeing/features/profile/screens/leaderboard_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final TextEditingController _nameController = TextEditingController();

  Stream<DocumentSnapshot<Map<String, dynamic>>> _getUserStatsStream() {
    if (user == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .snapshots();
  }

  // ✅ UPDATED RANK LOGIC (Based on Correct Answers)
  Future<int> _calculateMyRank(int myCorrectCount) async {
    if (myCorrectCount == 0) return 0;
    
    // Check karo kitne logo ke 'correct' score mujhse jyada hain
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('stats.correct', isGreaterThan: myCorrectCount)
        .count()
        .get();
        
    return query.count! + 1; 
  }

  void _showEditNameDialog(String currentName) {
    _nameController.text = currentName; 
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Profile Name"),
        content: TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: "Enter New Name",
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (_nameController.text.trim().isNotEmpty) {
                _updateName(_nameController.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> _updateName(String newName) async {
    if (user == null) return;
    try {
      await user!.updateDisplayName(newName);
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
        'displayName': newName,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Name updated to $newName successfully! ✅")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update name: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
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
          final String displayName = userData?['displayName'] ?? user?.displayName ?? 'User';

          int totalTests = stats['totalTests'] ?? 0;
          int totalQuestions = stats['totalQuestions'] ?? 0;
          int correct = stats['correct'] ?? 0;
          int wrong = stats['wrong'] ?? 0;
          
          double accuracy = totalQuestions == 0 ? 0 : (correct / totalQuestions) * 100;

          Map<String, dynamic> subjectPerformance = stats['subjects'] ?? {};
          String weakSubject = "Not enough data";
          double lowestAcc = 101;

          subjectPerformance.forEach((subject, data) {
            int subTotal = data['total'] ?? 0;
            int subCorrect = data['correct'] ?? 0;
            if (subTotal > 5) { 
              double acc = (subCorrect / subTotal) * 100;
              if (acc < lowestAcc) {
                lowestAcc = acc;
                weakSubject = subject;
              }
            }
          });

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              if (user != null) _buildUserCard(displayName),

              const SizedBox(height: 24),
              Text("Performance Overview", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 1.6,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  // ✅ Pass 'correct' count for Rank Calculation
                  _buildRankGridCard(correct), 
                  _buildStatCard("Accuracy", "${accuracy.toStringAsFixed(1)}%", Colors.purple),
                  _buildStatCard("Right Ans", "$correct", Colors.green),
                  _buildStatCard("Wrong Ans", "$wrong", Colors.red),
                ],
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: _buildSubjectCard(
                      "Total Tests", 
                      "$totalTests", 
                      Colors.blue.shade50, 
                      Colors.blue.shade800, 
                      Icons.assignment_turned_in_outlined
                    )
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        if (subjectPerformance.isNotEmpty) {
                          _showWeakTopicsDialog(subjectPerformance);
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: _buildSubjectCard("Need Focus", weakSubject, Colors.orange.shade50, Colors.orange.shade900, Icons.show_chart, isClickable: true),
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

  Widget _buildUserCard(String displayName) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Theme.of(context).colorScheme.primary,
              backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
              child: user?.photoURL == null
                  ? Text(
                      displayName.substring(0, 1).toUpperCase(), 
                      style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayName, 
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _showEditNameDialog(displayName),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.edit, size: 16, color: Theme.of(context).colorScheme.primary),
                        ),
                      ),
                    ],
                  ),
                  if (user?.email != null) Text(user!.email!, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankGridCard(int myCorrectCount) {
    return FutureBuilder<int>(
      // ✅ Using Correct Count for Rank
      future: _calculateMyRank(myCorrectCount),
      builder: (context, snapshot) {
        String rankText = "--";
        if (snapshot.hasData && snapshot.data != 0) {
          rankText = "#${snapshot.data}";
        } else if (myCorrectCount == 0) {
          rankText = "N/A";
        }

        return InkWell(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (c) => const LeaderboardScreen()));
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50, 
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(rankText, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Rank", style: TextStyle(fontSize: 13, color: Colors.amber.shade800, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios, size: 10, color: Colors.amber.shade800)
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ... (Baki saare widgets same hain: _buildStatCard, _buildSubjectCard, _buildRevisionBox, _startRevisionTest etc.)
  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildSubjectCard(String title, String subject, Color bgColor, Color textColor, IconData icon, {bool isClickable = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: isClickable ? Border.all(color: textColor.withOpacity(0.3)) : null,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: textColor.withOpacity(0.7)),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subject, 
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16), 
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (isClickable)
             Padding(
               padding: const EdgeInsets.only(top: 4.0),
               child: Icon(Icons.arrow_forward_ios_rounded, size: 12, color: textColor.withOpacity(0.6)),
             ),
        ],
      ),
    );
  }

  Widget _buildRevisionBox(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade100),
        boxShadow: [
          BoxShadow(color: Colors.blue.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.psychology_alt_rounded, color: Colors.indigo.shade600, size: 28),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Smart Revision", 
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)
                    ),
                    Text(
                      "Master your weak points", 
                      style: TextStyle(fontSize: 13, color: Colors.grey)
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            "Re-attempt questions you answered incorrectly. They will be removed once you master them (2 correct attempts).",
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade600,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _startRevisionTest(context),
              icon: const Icon(Icons.play_circle_outline_rounded),
              label: const Text("Start Practice Session (25 Q)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))
      ),
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Topics to Improve", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              const Text("Focus on these areas to boost your score", style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 20),
              
              if (weakTopics.isEmpty)
                Container(
                  padding: const EdgeInsets.all(30),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(Icons.emoji_events_rounded, size: 60, color: Colors.amber.shade300),
                      const SizedBox(height: 10),
                      const Text("No weak areas found yet!", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const Text("Keep practicing to maintain your streak.", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: weakTopics.length,
                    separatorBuilder: (ctx, i) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final topic = weakTopics[index];
                      int total = topic.value['total'];
                      int correct = topic.value['correct'];
                      double acc = (correct / total) * 100;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: Colors.red.shade50,
                          child: Icon(Icons.priority_high_rounded, color: Colors.red.shade400, size: 20),
                        ),
                        title: Text(topic.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(20)),
                          child: Text("${acc.toStringAsFixed(0)}% Acc", style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        subtitle: Text("Correct: $correct / $total", style: const TextStyle(fontSize: 12)),
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
          content: Text("No mistakes pending review! Outstanding! 🌟"),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.indigo,
        )
      );
      return;
    }
    List<Question> questions = rawData.map((e) {
      return Question.fromMap(e['parsedData'] as Map<String, dynamic>);
    }).toList();
    List<String> dbIds = rawData.map((e) => e['id'] as String).toList();

    AdManager.showInterstitialAd(() {
      if (context.mounted) {
        context.push('/practice-mcq', extra: {
          'questions': questions,
          'topicName': 'Smart Revision',
          'mode': 'test',
          'isRevision': true, 
          'dbIds': dbIds,     
        });
      }
    });
  }
}
