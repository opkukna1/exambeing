import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../../services/auth_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Get the current user from Firebase Auth
    final user = FirebaseAuth.instance.currentUser;
    final authService = AuthService();

    return Scaffold(
      // This screen doesn't need its own AppBar as it's inside the MainScreen shell
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
                      backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                      child: user.photoURL == null
                          ? Text(
                              user.displayName?.substring(0, 1).toUpperCase() ?? user.email?.substring(0, 1).toUpperCase() ?? 'U',
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
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (user.email != null)
                            Text(user.email!, style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          const SizedBox(height: 24),

          // --- Other Options ---
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('My Test History'),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
            onTap: () { /* Navigate to test history screen (to be built later) */ },
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
            onTap: () { /* Navigate to settings screen (to be built later) */ },
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
}
