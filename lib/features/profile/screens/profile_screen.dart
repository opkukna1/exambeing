import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../../services/auth_service.dart';

// ⬇️===== YEH HAI NAYA IMPORT (Stats Padhne Ke Liye) =====⬇️
import 'package:cloud_firestore/cloud_firestore.dart';
// ⬆️=======================================================⬆️

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  /// ⬇️===== YEH HAI NAYA FUNCTION (Stats Padhne Ke Liye) =====⬇️
  Stream<DocumentSnapshot<Map<String, dynamic>>> _getUserStatsStream(
      String? userId) {
    if (userId == null) {
      // Agar user login nahi hai (jo ki nahi hona chahiye), to khaali stream
      return const Stream.empty();
    }
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots();
  }
  // ⬆️=======================================================⬆️

  @override
  Widget build(BuildContext context) {
    // Get the current user from Firebase Auth
    final user = FirebaseAuth.instance.currentUser;
    final authService = AuthService();

    return Scaffold(
      // ⬇️===== YEH HAI NAYA APPBAR (Settings Icon Ke Saath) =====⬇️
      appBar: AppBar(
        title: const Text('My Profile'),
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () {
              // Yahaan hum /settings route par bhej rahe hain
              // Is route ko app_router.dart mein add karna hoga
              // context.push('/settings'); 
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings screen (to be built)'))
              );
            },
          ),
        ],
      ),
      // ⬆️=======================================================⬆️
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          if (user != null)
            // User Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: user.photoURL != null
                          ? NetworkImage(user.photoURL!)
                          : null,
                      child: user.photoURL == null
                          ? Text(
                              user.displayName
                                      ?.substring(0, 1)
                                      .toUpperCase() ??
                                  user.email?.substring(0, 1).toUpperCase() ??
                                  'U',
                              style: const TextStyle(fontSize: 24),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.displayName ?? 'No Name',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (user.email != null)
                            Text(user.email!,
                                style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          const SizedBox(height: 24),

          // ⬇️===== YEH HAI NAYA WIDGET (Stats Dikhane Ke Liye) =====⬇️
          Text("Your Progress",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),

          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _getUserStatsStream(user?.uid),
            builder: (context, snapshot) {
              // 1. Loading State
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // 2. Error State
              if (snapshot.hasError) {
                return const Center(
                    child: Text("Error loading stats."));
              }

              // 3. No Data (Naya user jisne test nahi diya)
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return Card(
                  color: Colors.blue.shade50,
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: Text("Start taking tests to see your stats!"),
                    ),
                  ),
                );
              }

              // 4. Data Mil Gaya
              final data = snapshot.data!.data()!;
              final int testsTaken = data['tests_taken'] ?? 0;
              final int questionsAnswered =
                  data['total_questions_answered'] ?? 0;
              final int correctAnswers =
                  data['total_correct_answers'] ?? 0;

              // Accuracy calculate karna (0 se divide na ho)
              double avgAccuracy = 0;
              if (questionsAnswered > 0) {
                avgAccuracy = (correctAnswers / questionsAnswered) * 100;
              }

              return Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatTile("Tests Taken", testsTaken.toString()),
                      _buildStatTile("Avg. Accuracy", "${avgAccuracy.toStringAsFixed(1)}%"),
                    ],
                  ),
                ),
              );
            },
          ),
          // ⬆️=======================================================⬆️

          const SizedBox(height: 24),

          // --- Other Options ---
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('My Test History'),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
            onTap: () {
              /* Navigate to test history screen (to be built later) */
            },
          ),
          
          const Divider(height: 32),

          // Logout Button
          ElevatedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              foregroundColor: Colors.red.shade800,
            ),
            onPressed: () async {
              await authService.signOut();
              if (context.mounted) {
                // The router's redirect logic will automatically handle navigation
                context.go('/login-hub');
              }
            },
          ),
        ],
      ),
    );
  }

  // ⬇️===== YEH HAI NAYA HELPER WIDGET (Stats Tile Banane Ke Liye) =====⬇️
  Widget _buildStatTile(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Colors.black54),
        ),
      ],
    );
  }
  // ⬆️=======================================================⬆️
}
