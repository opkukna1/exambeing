import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ✅ 1. FCM IMPORT
import 'package:firebase_messaging/firebase_messaging.dart';

// ✅ 2. AdManager Import
import 'package:exambeing/services/ad_manager.dart';

// ✅ 3. Test Generator Import
import 'package:exambeing/features/tests/screens/test_generator_screen.dart';

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
    AdManager.loadInterstitialAd(); // Ad Pre-load
    _saveDeviceToken(); // Token Save
  }

  // --- TOKEN SAVE FUNCTION (Logic Safe) ---
  Future<void> _saveDeviceToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.requestPermission(
        alert: true, badge: true, sound: true,
      );
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
    } catch (e) {
      debugPrint("❌ Error saving token: $e");
    }
  }

  // --- 🎉 LUCKY TRIAL LOGIC (Logic Safe) ---
  Future<void> _activateLuckyTrial() async {
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Column(
          children: [
            const Icon(Icons.celebration, size: 60, color: Colors.orange),
            const SizedBox(height: 10),
            Text("🎉 Congratulations!", style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 24)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text("You are our Lucky User #1000! 🏆", textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Text("3 MONTHS FREE PREMIUM", textAlign: TextAlign.center, style: TextStyle(fontSize: 20, color: Colors.blue, fontWeight: FontWeight.w900)),
            SizedBox(height: 8),
            Text("Access all Test Series and Notes for free for 90 days.", textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12)),
              onPressed: () => Navigator.pop(context),
              child: const Text("Claim Offer Now", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
      children: [
        _buildWelcomeCard(context),
        const SizedBox(height: 25),
        
        // 📅 1. Daily Test (Updated Design)
        _buildDailyTestCard(context),
        
        const SizedBox(height: 20),
        
        // ✨ 2. Custom Test & Notes Row
        Row(
          children: [
            Expanded(child: _buildModernCustomTestCard()),
            const SizedBox(width: 15),
            Expanded(child: _buildModernNotesCard()),
          ],
        ),

        const SizedBox(height: 30),

        // 📚 3. Test Series Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Popular Series 🏆", style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const Icon(Icons.arrow_forward, color: Colors.grey),
          ],
        ),
        const SizedBox(height: 15),
        _buildTestSeriesSection(context),
      ],
    );
  }

  // 🔥 NEW: Modern Custom Test Card (Full Screen Nav)
  Widget _buildModernCustomTestCard() {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF6A11CB), Color(0xFF2575FC)], // Purple-Blue
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            // ✅ FULL SCREEN NAVIGATION
            Navigator.push(
              context, 
              MaterialPageRoute(builder: (context) => const TestGeneratorScreen())
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text("Custom\nTest", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, height: 1.2)),
                    SizedBox(height: 5),
                    Text("Create Now", style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 📝 NEW: Modern Notes Card (Full Screen Nav)
  Widget _buildModernNotesCard() {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        border: Border.all(color: Colors.orange.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.orange.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            // ✅ FULL SCREEN NAVIGATION
            context.push('/public-notes'); 
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
                  child: const Icon(Icons.menu_book_rounded, color: Colors.orange, size: 24),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text("Quick\nNotes", style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold, height: 1.2)),
                    SizedBox(height: 5),
                    Text("Read Topics", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 📅 UPDATED: Daily Test Card
  Widget _buildDailyTestCard(BuildContext context) {
    final DateTime now = DateTime.now();
    final String todayDocId = DateFormat('yyyy-MM-dd').format(now);
    final String dateTitle = DateFormat('dd MMM').format(now);

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('DailyTests').doc(todayDocId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: LinearProgressIndicator());
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                Icon(Icons.coffee, color: Colors.grey.shade400, size: 30),
                const SizedBox(width: 15),
                const Text("No Test for today yet!", style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final subtitle = data['subtitle'] ?? "Daily Practice Test";
        final questionIds = List<String>.from(data['questionIds'] ?? []);
        
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Color(0xFF11998e), Color(0xFF38ef7d)], // Green Gradient
              begin: Alignment.topLeft, end: Alignment.bottomRight
            ),
            boxShadow: [
              BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () {
                AdManager.showInterstitialAd(() {
                  context.push('/test-screen', extra: {'ids': questionIds});
                });
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
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.circle, color: Colors.redAccent, size: 8),
                                const SizedBox(width: 6),
                                Text("LIVE • $dateTitle", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(subtitle, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 5),
                          Text("${questionIds.length} Questions", style: const TextStyle(color: Colors.white70, fontSize: 14)),
                        ],
                      ),
                    ),
                    Container(
                      height: 50, width: 50,
                      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.play_arrow_rounded, color: Color(0xFF11998e), size: 32),
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // 📚 UPDATED: Test Series Grid
  Widget _buildTestSeriesSection(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('testSeriesHome').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Text("No series available.");

        final seriesList = snapshot.data!.docs;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 0.85,
          ),
          itemCount: seriesList.length,
          itemBuilder: (context, index) {
            final data = seriesList[index].data() as Map<String, dynamic>;
            final title = data['title'] ?? "Series";
            final category = data['category'] ?? "Exam";
            
            Color accentColor = index % 2 == 0 ? Colors.purple : Colors.indigo;
            Color iconBg = index % 2 == 0 ? Colors.purple.shade50 : Colors.indigo.shade50;

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                   BoxShadow(color: Colors.grey.shade200, blurRadius: 5, offset: const Offset(0, 3)),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    if (data['type'] == 'subject') {
                      context.push('/subject-list', extra: {'seriesId': seriesList[index].id, 'seriesTitle': title});
                    } else {
                      context.push('/test-list', extra: {'seriesId': seriesList[index].id, 'subjectId': 'default', 'subjectTitle': title});
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 45, width: 45,
                          decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.menu_book, color: accentColor),
                        ),
                        const Spacer(),
                        Text(category.toUpperCase(), style: TextStyle(color: Colors.grey[500], fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text("View All", style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_forward_rounded, size: 14, color: accentColor)
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 👋 Welcome Card
  Widget _buildWelcomeCard(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hello, Aspirant 👋', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
            const SizedBox(height: 5),
            const Text('Let\'s Crack It!', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 24)),
          ],
        ),
        CircleAvatar(
          radius: 25,
          backgroundColor: Colors.grey[200],
          child: IconButton(icon: const Icon(Icons.notifications_none, color: Colors.black), onPressed: (){}),
        )
      ],
    );
  }
}
