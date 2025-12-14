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
    
    // ✅ Ad Pre-load
    AdManager.loadInterstitialAd();

    // ✅ TOKEN SAVE LOGIC
    _saveDeviceToken();
  }

  // --- TOKEN SAVE FUNCTION ---
  Future<void> _saveDeviceToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      FirebaseMessaging messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        String? token = await messaging.getToken();
        if (token != null) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'fcmToken': token,
            'platform': Theme.of(context).platform == TargetPlatform.android ? 'android' : 'ios',
            'lastTokenUpdate': DateTime.now().toIso8601String(),
          }, SetOptions(merge: true));
          debugPrint("✅ FCM Token Saved: $token");
        }
      } else {
        debugPrint("❌ User declined notification permission");
      }
    } catch (e) {
      debugPrint("❌ Error saving token: $e");
    }
  }

  // --- 🎉 LUCKY TRIAL LOGIC ---
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

        if (mounted) {
          _showLuckyDialog();
        }

        await prefs.setBool('lucky_trial_claimed_${user.uid}', true);
        
      } catch (e) {
        debugPrint("Error activating trial: $e");
      }
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
            Text(
              "🎉 Congratulations!",
              style: TextStyle(
                color: Colors.green.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              "You are our Lucky User #1000! 🏆",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              "As a special gift, you have received:",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              "3 MONTHS FREE PREMIUM",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20, 
                color: Colors.blue, 
                fontWeight: FontWeight.w900
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Access all Test Series and Notes for free for 90 days.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Claim Offer Now", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 10),
        ],
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
        
        // 1. Daily Test Card
        _buildDailyTestCard(context),
        
        const SizedBox(height: 16),

        // 2. Custom Test Button (Simple Card)
        Card(
          color: Colors.indigo.shade50,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: Colors.indigo,
              radius: 25,
              child: const Icon(Icons.auto_awesome, color: Colors.white),
            ),
            title: const Text(
              "Create Custom Test", 
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
            ),
            subtitle: const Text("Select topics & challenge yourself!"),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18, color: Colors.indigo),
            onTap: () {
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => const TestGeneratorScreen())
              );
            },
          ),
        ),
        
        const SizedBox(height: 16),

        // 🔥 3. MODERN NOTES CARD (Updated UI + Navigation Fix)
        _buildModernNotesCard(context),

        const SizedBox(height: 24),

        // 4. Test Series Section
        _buildTestSeriesSection(context),
      ],
    );
  }

  // 🔥 NEW MODERN NOTES CARD WIDGET
  Widget _buildModernNotesCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFFff9966), Color(0xFFff5e62)], // Sunset Orange Gradient
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFff5e62).withOpacity(0.4),
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
            // ✅ SOLUTION 1: context.push() use kiya taki Back button kaam kare
            context.push('/public-notes'); 
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
                          "SMART NOTES 📚",
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
                        "Quick Revision &\nShort Notes",
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
                          Text(
                            "Read Now",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                          ),
                          SizedBox(width: 5),
                          Icon(Icons.arrow_forward, color: Colors.white, size: 16),
                        ],
                      )
                    ],
                  ),
                ),
                // Decorative Image/Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- DAILY TEST CARD ---
  Widget _buildDailyTestCard(BuildContext context) {
    final DateTime now = DateTime.now();
    final String todayDocId = DateFormat('yyyy-MM-dd').format(now);
    final String dateTitle = DateFormat('dd MMMM yyyy').format(now);

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('DailyTests')
          .doc(todayDocId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Card(
            margin: const EdgeInsets.all(0),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.sentiment_dissatisfied, size: 40, color: Colors.grey),
                    const SizedBox(height: 10),
                    Text(
                      "Test for $dateTitle is not uploaded yet.",
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final subtitle = data['subtitle'] ?? "Daily Practice Test";
        final questionIds = List<String>.from(data['questionIds'] ?? []);
        
        return Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          margin: const EdgeInsets.all(0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_month_outlined, 
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Daily Target - $dateTitle",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.9),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.list_alt, size: 14, color: Theme.of(context).colorScheme.onPrimaryContainer),
                      const SizedBox(width: 6),
                      Text(
                        "${questionIds.length} Questions",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    onPressed: () {
                      AdManager.showInterstitialAd(() {
                        context.push('/test-screen', extra: {'ids': questionIds});
                      });
                    },
                    child: const Text(
                      "Start Today's Test",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTestSeriesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Test Series",
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('testSeriesHome').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text("No test series available right now."));
            }

            final seriesList = snapshot.data!.docs;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.9,
              ),
              itemCount: seriesList.length,
              itemBuilder: (context, index) {
                final series = seriesList[index];
                final data = series.data() as Map<String, dynamic>;
                
                final title = data['title'] ?? "N/A";
                final subtitle = data['subtitle'] ?? "View Tests";
                final category = data['category'] ?? "Exam";
                final String type = data['type'] ?? 'direct'; 
                
                Color cardColor = Colors.teal.shade50;
                if (data['colorCode'] != null) {
                  try {
                    cardColor = Color(int.parse(data['colorCode']));
                  } catch (e) { }
                }

                return Card(
                  color: cardColor.withOpacity(0.3),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(15),
                    onTap: () {
                      if (type == 'subject') {
                        context.push('/subject-list', extra: {
                          'seriesId': series.id,
                          'seriesTitle': title,
                        });
                      } else {
                        context.push('/test-list', extra: {
                          'seriesId': series.id,
                          'subjectId': 'default',
                          'subjectTitle': title,
                        });
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            category.toUpperCase(),
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildWelcomeCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
            Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome!',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ready to start your preparation?',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
