import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Add this to pubspec.yaml for Date formatting

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  // 0 = All Time, 1 = Monthly
  int _selectedTab = 0; 

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final currentMonthName = DateFormat('MMMM').format(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.grey[50], // Modern light background
      body: Column(
        children: [
          // ---------------------------------------------
          // 1. MODERN HEADER WITH TOGGLE
          // ---------------------------------------------
          Container(
            padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 25),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFFB300), Color(0xFFFF8F00)], // Amber Gradient
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(color: Colors.orangeAccent, blurRadius: 10, offset: Offset(0, 5))
              ]
            ),
            child: Column(
              children: [
                const Text(
                  "Leaderboard",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 5),
                const Text(
                  "Compete with the best!",
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
                const SizedBox(height: 20),
                
                // Toggle Switch
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    children: [
                      _buildTabButton("All Time 🏆", 0),
                      _buildTabButton("$currentMonthName 📅", 1),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ---------------------------------------------
          // 2. LEADERBOARD LIST
          // ---------------------------------------------
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.emoji_events_outlined, size: 60, color: Colors.grey[300]),
                        const SizedBox(height: 10),
                        const Text("No champions yet!", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                final users = snapshot.data!.docs;
                
                // Find My Rank Logic
                int myRank = -1;
                int myScore = 0;
                for (int i = 0; i < users.length; i++) {
                  if (users[i].id == myUid) {
                    myRank = i + 1;
                    final data = users[i].data() as Map<String, dynamic>;
                    final stats = data['stats'] as Map<String, dynamic>? ?? {};
                    myScore = _selectedTab == 0 
                        ? (stats['correct'] ?? 0) 
                        : (stats['monthly_score'] ?? 0);
                    break;
                  }
                }

                return Stack(
                  children: [
                    // THE LIST
                    ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 100), // Bottom padding for sticky bar
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        return _buildUserCard(users[index], index, myUid);
                      },
                    ),

                    // ---------------------------------------------
                    // 3. STICKY BOTTOM BAR (MY RANK)
                    // ---------------------------------------------
                    if (myUid != null)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))
                            ],
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20))
                          ),
                          child: Row(
                            children: [
                              const Text("You", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const Spacer(),
                              if (myRank != -1) ...[
                                Text("#$myRank", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.deepPurple)),
                                const SizedBox(width: 15),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20)
                                  ),
                                  child: Text("$myScore pts", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                                )
                              ] else ...[
                                // If user is not in top 100/10
                                Text("Not in Top ${_selectedTab == 0 ? '100' : '10'}", style: const TextStyle(color: Colors.grey, fontSize: 12))
                              ]
                            ],
                          ),
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

  // 🔥 SWITCH STREAMS BASED ON TAB
  Stream<QuerySnapshot> _getStream() {
    CollectionReference usersRef = FirebaseFirestore.instance.collection('users');

    if (_selectedTab == 0) {
      // ALL TIME: Sort by total correct answers (Top 100)
      return usersRef.orderBy('stats.correct', descending: true).limit(100).snapshots();
    } else {
      // MONTHLY: Sort by monthly_score (Top 10)
      // Note: Ensure you have a 'monthly_score' field in Firestore
      return usersRef.orderBy('stats.monthly_score', descending: true).limit(10).snapshots();
    }
  }

  // ✨ MODERN TOGGLE BUTTON
  Widget _buildTabButton(String text, int index) {
    bool isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected ? [const BoxShadow(color: Colors.black12, blurRadius: 5)] : []
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.orange[800] : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }

  // 🎨 USER CARD DESIGN
  Widget _buildUserCard(DocumentSnapshot doc, int index, String? myUid) {
    final data = doc.data() as Map<String, dynamic>;
    final String name = data['displayName'] ?? 'Unknown User';
    final stats = data['stats'] as Map<String, dynamic>? ?? {};
    
    // Choose score based on tab
    final int score = _selectedTab == 0 
        ? (stats['correct'] ?? 0) 
        : (stats['monthly_score'] ?? 0);

    final bool isMe = doc.id == myUid;
    final int rank = index + 1;

    // Rank Styling
    Color? rankColor;
    Widget rankWidget;
    double elevation = 2;

    if (rank == 1) {
      rankColor = const Color(0xFFFFD700); // Gold
      rankWidget = const Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 30);
    } else if (rank == 2) {
      rankColor = const Color(0xFFC0C0C0); // Silver
      rankWidget = const Icon(Icons.emoji_events, color: Color(0xFFC0C0C0), size: 30);
    } else if (rank == 3) {
      rankColor = const Color(0xFFCD7F32); // Bronze
      rankWidget = const Icon(Icons.emoji_events, color: Color(0xFFCD7F32), size: 30);
    } else {
      rankWidget = Text(
        "#$rank",
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.grey),
      );
      elevation = 0.5;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isMe ? Colors.orange.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: isMe ? Border.all(color: Colors.orange, width: 1.5) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        leading: SizedBox(
          width: 40,
          child: Center(child: rankWidget),
        ),
        title: Text(
          name,
          style: TextStyle(
            fontWeight: isMe ? FontWeight.bold : FontWeight.w600,
            fontSize: 16,
          ),
          maxLines: 1, overflow: TextOverflow.ellipsis,
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: rankColor?.withOpacity(0.2) ?? Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            "$score",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: rankColor != null ? Colors.black87 : Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }
}
