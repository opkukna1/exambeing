import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("🏆 Top 100 Champions"),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: Colors.amber,
            child: const Column(
              children: [
                Icon(Icons.emoji_events_rounded, size: 50, color: Colors.black),
                SizedBox(height: 10),
                Text(
                  "Leaderboard",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                // ✅ UPDATED TEXT
                Text("Based on total CORRECT answers", style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
          
          // List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  // ✅ CHANGE 1: Ab 'correct' ke adhar par sort hoga
                  .orderBy('stats.correct', descending: true)
                  .limit(100) 
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No champions yet. Be the first!"));
                }

                final users = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: users.length,
                  padding: const EdgeInsets.only(bottom: 20),
                  itemBuilder: (context, index) {
                    final data = users[index].data() as Map<String, dynamic>;
                    
                    final String name = data['displayName'] ?? 'Unknown User';
                    final stats = data['stats'] as Map<String, dynamic>? ?? {};
                    
                    // ✅ CHANGE 2: Correct answers dikhana hai
                    final int correctAns = stats['correct'] ?? 0;
                    
                    final isMe = users[index].id == myUid;

                    // Rank Styling
                    Widget? leadingWidget;
                    Color cardColor = Colors.white;
                    double elevation = 0.5;

                    // ✅ CHANGE 3: Rank Number Logic
                    if (index == 0) {
                      leadingWidget = const Icon(Icons.emoji_events, color: Colors.amber, size: 32);
                      cardColor = const Color(0xFFFFF8E1); 
                    } else if (index == 1) {
                      leadingWidget = const Icon(Icons.emoji_events, color: Colors.grey, size: 32);
                      cardColor = const Color(0xFFF5F5F5); 
                    } else if (index == 2) {
                      leadingWidget = const Icon(Icons.emoji_events, color: Colors.brown, size: 32);
                      cardColor = const Color(0xFFEFEBE9); 
                    } else {
                      // Normal Rank Number
                      leadingWidget = CircleAvatar(
                        backgroundColor: Colors.grey.shade100,
                        radius: 16,
                        child: Text(
                          "${index + 1}", 
                          style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.bold)
                        ),
                      );
                    }

                    if (isMe) {
                      cardColor = Colors.blue.shade50;
                      elevation = 2;
                    }

                    return Card(
                      color: cardColor,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      elevation: elevation,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: isMe ? const BorderSide(color: Colors.blue, width: 1.5) : BorderSide.none
                      ),
                      child: ListTile(
                        leading: SizedBox(
                          width: 40, 
                          child: Center(child: leadingWidget),
                        ),
                        title: Text(
                          name, 
                          style: TextStyle(
                            fontWeight: isMe ? FontWeight.bold : FontWeight.w500,
                            color: Colors.black87,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.blue.withOpacity(0.2) : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(20)
                          ),
                          child: Text(
                            "$correctAns Correct",  // ✅ Updated Label
                            style: TextStyle(
                              color: isMe ? Colors.blue.shade900 : Colors.green.shade800, 
                              fontWeight: FontWeight.bold, 
                              fontSize: 12
                            )
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
