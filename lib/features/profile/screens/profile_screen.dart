import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart'; // GoRouter import kiya
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/auth_service.dart'; // AuthService import kiya (Logout ke liye Settings mein zaroorat padegi)

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Stream<DocumentSnapshot<Map<String, dynamic>>> _getUserStatsStream(
      String? userId) {
    if (userId == null) {
      return const Stream.empty();
    }
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    // AuthService ko yahaan define karne ki zaroorat nahi, kyonki Logout button hat gaya hai
    // final authService = AuthService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () {
              // ⬇️===== BADLAAV YAHAN HAI =====⬇️
              context.push('/settings'); // Ab Settings page par jaayega
              // ⬆️===========================⬆️
            },
          ),
        ],
      ),
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

          // Your Progress Section (Yeh waisa hi hai)
          Text("Your Progress",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _getUserStatsStream(user?.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const Center(child: Text("Error loading stats."));
              }
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
              final data = snapshot.data!.data()!;
              final int testsTaken = data['tests_taken'] ?? 0;
              final int questionsAnswered =
                  data['total_questions_answered'] ?? 0;
              final int correctAnswers =
                  data['total_correct_answers'] ?? 0;
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

          // ⬇️===== Test History ListTile Hata Diya Gaya Hai =====⬇️
          // const SizedBox(height: 24),
          // ListTile( ... My Test History ... ),
          // ⬆️===================================================⬆️

          // ⬇️===== Divider aur Logout Button Hata Diya Gaya Hai =====⬇️
          // const Divider(height: 32),
          // ElevatedButton.icon( ... Logout ... ),
          // ⬆️=======================================================⬆️
        ],
      ),
    );
  }

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
}
