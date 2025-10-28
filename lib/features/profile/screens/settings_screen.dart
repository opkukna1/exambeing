import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../../services/auth_service.dart'; // AuthService import kiya

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Abhi ke liye toggles ka state simple variables mein rakhte hain
  bool _isDarkMode = false;
  bool _isSoundDisabled = false;
  bool _isVibrationDisabled = false;

  final AuthService _authService = AuthService(); // AuthService instance banaya

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton( // Back button add kiya
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(), // Profile screen par wapas jao
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
        children: [
          // User Info Section (Screenshot jaisa)
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 30.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundImage: user.photoURL != null
                        ? NetworkImage(user.photoURL!)
                        : null,
                    // Placeholder image ya initial (Screenshot mein cartoon tha)
                    child: user.photoURL == null
                        ? const Icon(Icons.person, size: 40) // Simple Icon
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Hello!",
                           style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          user.displayName ?? user.email ?? 'User', // 'Yes' ki jagah naam
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  IconButton( // Edit Icon
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () {
                      // TODO: Edit Profile functionality add karna hai
                       ScaffoldMessenger.of(context).showSnackBar(
                         const SnackBar(content: Text('Edit Profile (to be built)'))
                       );
                    },
                  ),
                ],
              ),
            ),

          // Settings Section Title
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              'SETTINGS',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),

          // Dark Mode Toggle
          _buildSettingTile(
            context,
            icon: Icons.brightness_6_outlined,
            title: 'Dark Mode',
            value: _isDarkMode,
            onChanged: (newValue) {
              setState(() => _isDarkMode = newValue);
              // TODO: Yahaan Dark Mode ki actual functionality add karni hogi
              // (Using Provider or ThemeNotifier)
              ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text('Dark Mode ${_isDarkMode ? "ON" : "OFF"} (UI Only)'))
               );
            },
          ),

          // Disable Sound Toggle
          _buildSettingTile(
            context,
            icon: _isSoundDisabled ? Icons.volume_off_outlined : Icons.volume_up_outlined,
            title: 'Disable Sound',
            value: _isSoundDisabled,
            onChanged: (newValue) {
              setState(() => _isSoundDisabled = newValue);
              // TODO: Sound disable karne ki functionality add karni hogi
               ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text('Sound ${_isSoundDisabled ? "Disabled" : "Enabled"} (UI Only)'))
               );
            },
          ),

          // Disable Vibration Toggle
          _buildSettingTile(
            context,
            icon: _isVibrationDisabled ? Icons.vibration : Icons.vibration, // Icon change kar sakte hain
            title: 'Disable Vibration',
            value: _isVibrationDisabled,
            onChanged: (newValue) {
              setState(() => _isVibrationDisabled = newValue);
              // TODO: Vibration disable karne ki functionality add karni hogi
              ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text('Vibration ${_isVibrationDisabled ? "Disabled" : "Enabled"} (UI Only)'))
               );
            },
          ),

          const SizedBox(height: 30),

          // General Section Title
           Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              'GENERAL',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),

          // General Links
          _buildGeneralLink(context, icon: Icons.privacy_tip_outlined, title: 'Privacy Policy'),
          _buildGeneralLink(context, icon: Icons.description_outlined, title: 'Terms & Conditions'),
          _buildGeneralLink(context, icon: Icons.receipt_long_outlined, title: 'Refund Policy'),
          _buildGeneralLink(context, icon: Icons.feedback_outlined, title: 'Feedback'),
          _buildGeneralLink(context, icon: Icons.info_outline, title: 'About Us'),

          const SizedBox(height: 40),

          // Logout Button (Screenshot jaisa)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0), // Side se thoda gap
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                 foregroundColor: Colors.red.shade700,
                 side: BorderSide(color: Colors.red.shade200),
                 padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('LOGOUT', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () async {
                 await _authService.signOut();
                 if (context.mounted) {
                   // Login Hub par bhejo
                   context.go('/login-hub');
                 }
              },
            ),
          ),

          const SizedBox(height: 20), // Neeche thoda gap
        ],
      ),
    );
  }

  // Helper widget for setting toggles
  Widget _buildSettingTile(BuildContext context, {required IconData icon, required String title, required bool value, required ValueChanged<bool> onChanged}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.grey.shade700),
      title: Text(title),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.deepPurple, // Match theme
      ),
    );
  }

   // Helper widget for general links
  Widget _buildGeneralLink(BuildContext context, {required IconData icon, required String title}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.grey.shade700),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
       onTap: () {
          // TODO: In links ke liye functionality add karni hogi (WebView ya URL Launcher)
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('$title page (to be built)'))
           );
        },
    );
  }
}
