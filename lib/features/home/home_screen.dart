import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        const SizedBox(height: 24),

        // 2. Notes Card
        _buildActionCard(
          context: context,
          icon: Icons.note_alt_outlined,
          title: 'Notes',
          subtitle: 'Read subject-wise short notes',
          color: Colors.orange,
          onTap: () => context.go('/public-notes'),
        ),
        const SizedBox(height: 24),

        // 3. Test Series Section (UPDATED LOGIC HERE)
        _buildTestSeriesSection(context),
      ],
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
                      context.go('/test-screen', extra: {'ids': questionIds});
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

  // --- ✅ UPDATED TEST SERIES SECTION (Dynamic Routing) ---
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
                
                // ✅ NAYA FIELD: type ('direct' or 'subject')
                // Agar type nahi mila, to default 'direct' rahega
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
                      // 🚀 DYNAMIC ROUTING LOGIC 🚀
                      if (type == 'subject') {
                        // RPSC jaisa flow (Subject List -> Topic List)
                        context.go('/subject-list', extra: {
                          'seriesId': series.id,
                          'seriesTitle': title,
                        });
                      } else {
                        // CET jaisa flow (Direct Test List)
                        context.go('/test-list', extra: series.id);
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

  Widget _buildActionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required MaterialColor color,
    required VoidCallback onTap,
  }) {
    Color iconColor = Theme.of(context).brightness == Brightness.dark 
                     ? color.shade300 
                     : color;
    Color iconBgColor = Theme.of(context).brightness == Brightness.dark
                     ? color.shade900.withOpacity(0.5)
                     : color.withOpacity(0.2);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircleAvatar(
                  radius: 28,
                  backgroundColor: iconBgColor,
                  child: Icon(icon, color: iconColor, size: 32)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: Theme.of(context).textTheme.bodySmall?.color, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
