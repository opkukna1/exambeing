import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../../services/auth_service.dart';
import 'package:provider/provider.dart';
import '../../../services/theme_provider.dart';

// ⬇️===== NAYA IMPORT =====⬇️
import 'package:url_launcher/url_launcher.dart';
// ⬆️======================⬆️


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isSoundDisabled = false;
  bool _isVibrationDisabled = false;
  final AuthService _authService = AuthService();

  // ⬇️===== NAYA HELPER FUNCTION =====⬇️
  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      // Agar URL nahi khul paaya to error dikhao
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $urlString')),
        );
      }
    }
  }
  // ⬆️=============================⬆️


  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final themeProvider = Provider.of<ThemeProvider>(context);

    // ⬇️===== AAPKA DOMAIN YAHAN DEFINE KARO =====⬇️
    // Yahaan 'https://' lagana zaroori hai
    const String baseUrl = "https://exambeing.com"; // <-- Apna domain daalein
    // ⬆️========================================⬆️

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
        children: [
          // User Info Section
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
                    child: user.photoURL == null
                        ? const Icon(Icons.person, size: 40)
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
                          user.displayName ?? user.email ?? 'User',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () {
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
            child: Text('SETTINGS', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
          ),

          // Dark Mode Toggle
          _buildSettingTile(
            context,
            icon: themeProvider.themeMode == ThemeMode.dark ? Icons.brightness_7_outlined : Icons.brightness_4_outlined,
            title: 'Dark Mode',
            value: themeProvider.themeMode == ThemeMode.dark,
            onChanged: (newValue) {
              themeProvider.toggleTheme();
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
               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sound ${_isSoundDisabled ? "Disabled" : "Enabled"} (UI Only)')));
            },
          ),
          // Disable Vibration Toggle
          _buildSettingTile(
            context,
            icon: Icons.vibration,
            title: 'Disable Vibration',
            value: _isVibrationDisabled,
            onChanged: (newValue) {
              setState(() => _isVibrationDisabled = newValue);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Vibration ${_isVibrationDisabled ? "Disabled" : "Enabled"} (UI Only)')));
            },
          ),

          const SizedBox(height: 30),

          // General Section Title
           Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text('GENERAL', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
          ),

          // ⬇️===== GENERAL LINKS (UPDATED onTap) =====⬇️
          _buildGeneralLink(context, icon: Icons.privacy_tip_outlined, title: 'Privacy Policy', url: '$baseUrl/privacy'), // Use privacy.md -> /privacy
          _buildGeneralLink(context, icon: Icons.description_outlined, title: 'Terms & Conditions', url: '$baseUrl/terms'), // Use terms.md -> /terms
          _buildGeneralLink(context, icon: Icons.receipt_long_outlined, title: 'Refund Policy', url: '$baseUrl/refund'), // Use refund.md -> /refund
          _buildGeneralLink(context, icon: Icons.feedback_outlined, title: 'Feedback', url: '$baseUrl/feedback'), // Use feedback.md -> /feedback
          _buildGeneralLink(context, icon: Icons.info_outline, title: 'About Us', url: '$baseUrl/about'), // Use about.md -> /about
          // ⬆️=======================================⬆️

          const SizedBox(height: 40),

          // Logout Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
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
                   context.go('/login-hub');
                 }
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSettingTile(BuildContext context, {required IconData icon, required String title, required bool value, required ValueChanged<bool> onChanged}) {
    Color? iconColor = Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade400 : Colors.grey.shade700;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      trailing: Switch(value: value, onChanged: onChanged, activeColor: Colors.deepPurple),
    );
  }

   // ⬇️===== HELPER WIDGET UPDATED =====⬇️
  Widget _buildGeneralLink(BuildContext context, {required IconData icon, required String title, required String url}) {
    Color? iconColor = Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade400 : Colors.grey.shade700;
    Color? arrowColor = Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade600 : Colors.grey;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: arrowColor),
      // ⬇️ Launch URL on tap ⬇️
       onTap: () => _launchURL(url),
      // ⬆️====================⬆️
    );
  }
  // ⬆️=============================⬆️
}
