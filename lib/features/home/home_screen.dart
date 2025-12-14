import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Imports
import 'package:exambeing/services/ad_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  
  @override
  void initState() {
    super.initState();
    _activateLuckyTrial();
    AdManager.loadInterstitialAd();
    _saveDeviceToken();
  }

  // --- TOKEN SAVE & LUCKY TRIAL LOGIC (Same as before) ---
  Future<void> _saveDeviceToken() async {
    // ... (Purana code same rakhein)
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.requestPermission(alert: true, badge: true, sound: true);
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        String? token = await messaging.getToken();
        if (token != null) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'fcmToken': token,
            'platform': Theme.of(context).platform == TargetPlatform.android ? 'android' : 'ios',
            'lastTokenUpdate': DateTime.now().toIso8601String(),
          }, SetOptions(merge: true));
        }
      }
    } catch (e) { debugPrint("Error: $e"); }
  }

  Future<void> _activateLuckyTrial() async {
    // ... (Purana code same rakhein)
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    bool hasClaimedOffer = prefs.getBool('lucky_trial_claimed_${user.uid}') ?? false;
    if (!hasClaimedOffer) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'isPremium': true,
          'premiumExpiry': DateTime.now().add(const Duration(days: 90)).toIso8601String(),
          'planType': 'Lucky Trial (3 Months)',
        }, SetOptions(merge: true));
        if (mounted) _showLuckyDialog();
        await prefs.setBool('lucky_trial_claimed_${user.uid}', true);
      } catch (e) { debugPrint("Error: $e"); }
    }
  }

  void _showLuckyDialog() {
    // ... (Dialog code same rakhein)
     showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Column(children: [Icon(Icons.celebration, size: 60, color: Colors.orange), SizedBox(height: 10), Text("🎉 Congratulations!", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))]),
        content: const Text("You got 3 Months Premium!", textAlign: TextAlign.center),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Claim"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildWelcomeCard(context),
        const SizedBox(height: 24),
        
        // 1. Daily Test
        _buildDailyTestCard(context),
        
        const SizedBox(height: 16),

        // 🔥 2. CUSTOM TEST BUTTON (Updated Modern UI)
        _buildModernCustomTestCard(context),
        
        const SizedBox(height: 16),

        // 🔥 3. SMART NOTES BUTTON (Orange)
        _buildModernNotesCard(context),

        const SizedBox(height: 24),

        // 4. Test Series
        _buildTestSeriesSection(context),
      ],
    );
  }

  // 🔵 NEW: MODERN CUSTOM TEST CARD (Indigo Gradient)
  Widget _buildModernCustomTestCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF6a11cb), Color(0xFF2575fc)], // Indigo-Blue Gradient
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2575fc).withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            // ✅ Full Screen Navigation Path
            context.push('/test-generator'); 
          },
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          "SELF CHALLENGE 🎯",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Create Custom\nTest & Quiz",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: const [
                          Text("Start Now", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                          SizedBox(width: 5),
                          Icon(Icons.arrow_forward, color: Colors.white, size: 16),
                        ],
                      )
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🟠 MODERN NOTES CARD (Orange Gradient - Same as before)
  Widget _buildModernNotesCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFFff9966), Color(0xFFff5e62)], // Orange Gradient
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: const Color(0xFFff5e62).withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.push('/public-notes'),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                        child: const Text("SMART NOTES 📚", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ),
                      const SizedBox(height: 10),
                      const Text("Quick Revision &\nShort Notes", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, height: 1.2)),
                      const SizedBox(height: 8),
                      Row(children: const [Text("Read Now", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)), SizedBox(width: 5), Icon(Icons.arrow_forward, color: Colors.white, size: 16)]),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ... (Baki saare widgets - DailyTestCard, TestSeriesSection, WelcomeCard same raheinge)
  // Copy-paste them from previous code to keep file complete.
  
  Widget _buildDailyTestCard(BuildContext context) {
    // (Purana code rakhein)
    return Card(child: Padding(padding: EdgeInsets.all(20), child: Text("Daily Test Loading..."))); // Placeholder for brevity
  }

  Widget _buildTestSeriesSection(BuildContext context) {
    // (Purana StreamBuilder code rakhein)
    return Container(); // Placeholder
  }

  Widget _buildWelcomeCard(BuildContext context) {
    // (Purana code rakhein)
    return Container(padding: EdgeInsets.all(20), child: Text("Welcome!")); // Placeholder
  }
}
