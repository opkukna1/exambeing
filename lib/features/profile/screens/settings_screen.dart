import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../../services/auth_service.dart'; // AuthService import kiya

// ⬇️===== NAYE IMPORTS =====⬇️
import 'package:provider/provider.dart';
import '../../../services/theme_provider.dart'; // Hamari ThemeProvider file
// ⬆️=======================⬆️


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // _isDarkMode hata diya gaya hai
  bool _isSoundDisabled = false;
  bool _isVibrationDisabled = false;

  final AuthService _authService = AuthService(); // AuthService instance banaya

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    // ⬇️===== THEME PROVIDER KO ACCESS KARO =====⬇️
    final themeProvider = Provider.of<ThemeProvider>(context);
    // ⬆️=========================================⬆️

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

          // ⬇️===== DARK MODE TOGGLE (UPDATED) =====⬇️
          _buildSettingTile(
            context,
            icon: themeProvider.themeMode == ThemeMode.dark
                 ? Icons.brightness_7_outlined // Light icon dikhao agar dark mode hai
                 : Icons.brightness_4_outlined, // Dark icon dikhao agar light mode hai
            title: 'Dark Mode',
            value: themeProvider.themeMode == ThemeMode.dark, // Value provider se lo
            onChanged: (newValue) {
              themeProvider.toggleTheme(); // Theme badalne ke liye provider ka function call karo
            },
          ),
          // ⬆️=======================================⬆️

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
            icon: Icons.vibration, // Same icon rakhte hain
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
    // ⬇️ Text ka color theme ke hisaab se badlega ⬇️
    Color? iconColor = Theme.of(context).brightness == Brightness.dark
                     ? Colors.grey.shade400
                     : Colors.grey.shade700;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: iconColor), // Icon color bhi badlega
      title: Text(title), // Text color theme se lega
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.deepPurple, // Match theme
      ),
    );
  }

   // Helper widget for general links
  Widget _buildGeneralLink(BuildContext context, {required IconData icon, required String title}) {
     // ⬇️ Text ka color theme ke hisaab se badlega ⬇️
    Color? iconColor = Theme.of(context).brightness == Brightness.dark
                     ? Colors.grey.shade400
                     : Colors.grey.shade700;
    Color? arrowColor = Theme.of(context).brightness == Brightness.dark
                     ? Colors.grey.shade600
                     : Colors.grey;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: arrowColor),
       onTap: () {
          // TODO: In links ke liye functionality add karni hogi (WebView ya URL Launcher)
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('$title page (to be built)'))
           );
        },
    );
  }
}
