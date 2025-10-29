import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../../services/auth_service.dart';
import 'package:provider/provider.dart';
import '../../../services/theme_provider.dart';
import 'package:url_launcher/url_launcher.dart';


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Sound and Vibration state variables hata diye gaye hain
  final AuthService _authService = AuthService();

  // URL Launcher function
  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $urlString')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Aapka domain
    const String baseUrl = "https://exambeing.com";

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
                  // ⬇️===== Edit Icon Hata Diya Gaya Hai =====⬇️
                  // IconButton(...),
                  // ⬆️=======================================⬆️
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
          // ⬇️===== Sound aur Vibration Hata Diye Gaye Hain =====⬇️
          // _buildSettingTile(... Sound ...),
          // _buildSettingTile(... Vibration ...),
          // ⬆️==================================================⬆️

          const SizedBox(height: 30),

          // General Section Title
           Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text('GENERAL', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
          ),

          // General Links
          _buildGeneralLink(context, icon: Icons.privacy_tip_outlined, title: 'Privacy Policy', url: '$baseUrl/privacy'),
          _buildGeneralLink(context, icon: Icons.description_outlined, title: 'Terms & Conditions', url: '$baseUrl/terms'),
          _buildGeneralLink(context, icon: Icons.receipt_long_outlined, title: 'Refund Policy', url: '$baseUrl/refund'),
          _buildGeneralLink(context, icon: Icons.feedback_outlined, title: 'Feedback', url: '$baseUrl/feedback'),
          _buildGeneralLink(context, icon: Icons.info_outline, title: 'About Us', url: '$baseUrl/about'),

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

  // Helper widget for setting toggles
  Widget _buildSettingTile(BuildContext context, {required IconData icon, required String title, required bool value, required ValueChanged<bool> onChanged}) {
    Color? iconColor = Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade400 : Colors.grey.shade700;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      trailing: Switch(value: value, onChanged: onChanged, activeColor: Colors.deepPurple),
    );
  }

   // Helper widget for general links
  Widget _buildGeneralLink(BuildContext context, {required IconData icon, required String title, required String url}) {
    Color? iconColor = Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade400 : Colors.grey.shade700;
    Color? arrowColor = Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade600 : Colors.grey;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: arrowColor),
      onTap: () => _launchURL(url),
    );
  }
}
