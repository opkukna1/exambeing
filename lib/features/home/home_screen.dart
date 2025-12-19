import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // 🔥 For AI Result

// ✅ IMPORTS
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:exambeing/services/ad_manager.dart';
import 'package:exambeing/features/tests/screens/test_generator_screen.dart';
import 'package:exambeing/services/ai_analysis_service.dart'; // 🔥 Your AI Service
import 'package:badges/badges.dart' as badges;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _displayName = "Aspirant";

  @override
  void initState() {
    super.initState();
    _loadUserName(); // Load Name
    _activateLuckyTrial();
    AdManager.loadInterstitialAd();
    _saveDeviceToken();
  }

  // --- 1. GET USER NAME ---
  void _loadUserName() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.displayName != null && user.displayName!.isNotEmpty) {
      setState(() {
        // Sirf First Name dikhayenge (e.g. "Rahul" instead of "Rahul Kumar")
        _displayName = user.displayName!.split(' ')[0];
      });
    }
  }

  // --- TOKEN & TRIAL LOGIC ---
  Future<void> _saveDeviceToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.requestPermission(alert: true, badge: true, sound: true);
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        String? token = await messaging.getToken();
        if (token != null) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'fcmToken': token, 'platform': Theme.of(context).platform == TargetPlatform.android ? 'android' : 'ios', 'lastTokenUpdate': DateTime.now().toIso8601String(),
          }, SetOptions(merge: true));
        }
      }
    } catch (e) { debugPrint("Error saving token: $e"); }
  }

  Future<void> _activateLuckyTrial() async {
     final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    bool hasClaimedOffer = prefs.getBool('lucky_trial_claimed_${user.uid}') ?? false;
    if (!hasClaimedOffer) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'isPremium': true, 'premiumExpiry': DateTime.now().add(const Duration(days: 90)).toIso8601String(), 'planType': 'Lucky Trial (3 Months)',
        }, SetOptions(merge: true));
        if (mounted) _showLuckyDialog();
        await prefs.setBool('lucky_trial_claimed_${user.uid}', true);
      } catch (e) { debugPrint("Error: $e"); }
    }
  }

  void _showLuckyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("🎉 Congratulations!"),
        content: const Text("You got 3 Months Free Premium!"),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Claim"))],
      ),
    );
  }

  // --- 🤖 AI ANALYSIS LOGIC (FIXED: Timeout & Crash Proof) ---
  void _onAiAnalyzePressed() async {
    // 1. Loading Dialog Show karein (White Background taaki Black Screen na lage)
    showDialog(
      context: context,
      barrierDismissible: false, // User click karke band na kar sake
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        content: Row(
          children: const [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text("AI is thinking...\n(Please wait)", style: TextStyle(fontSize: 14))),
          ],
        ),
      ),
    );

    String result = "";

    try {
      final service = AiAnalysisService();
      
      // 2. Data Fetch karein (WITH 15 SECOND TIMEOUT)
      // Agar 15 second mein jawab nahi aaya, to ye error message dega
      result = await service.getAnalysis().timeout(
        const Duration(seconds: 15), 
        onTimeout: () => "Error: AI took too long to respond. Please check internet.",
      );

    } catch (e) {
      // Agar koi bhi error aaya
      result = "Error: Something went wrong ($e)";
    } finally {
      // 3. FINALLY BLOCK (Ye Hamesha Chalega)
      // Chahe success ho ya error, Dialog band hona hi chahiye
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context); 
      }
    }

    // 4. Result Handle karein (Dialog band hone ke baad)
    if (result == "LIMIT_REACHED") {
      _showDialog("Limit Reached 🛑", "You have used your 5 free AI analysis for this month.");
    } else if (result == "NO_DATA") {
      _showDialog("No Data 📊", "Please attempt at least one test so AI can analyze your performance.");
    } else if (result.startsWith("Error")) {
       _showDialog("Connection Error ⚠️", result);
    } else {
      _showAnalysisResult(result);
    }
  }

  void _showDialog(String title, String msg) {
    showDialog(context: context, builder: (c) => AlertDialog(title: Text(title), content: Text(msg), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("OK"))]));
  }

  void _showAnalysisResult(String markdownText) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75, maxChildSize: 0.9, minChildSize: 0.5, expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 20),
                  Row(children: const [
                    Icon(Icons.psychology, color: Colors.deepPurple, size: 30),
                    SizedBox(width: 10),
                    Text("Your AI Performance Report", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ]),
                  const Divider(),
                  Expanded(
                    child: Markdown(
                      data: markdownText,
                      controller: scrollController,
                      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                        p: const TextStyle(fontSize: 15, height: 1.5, color: Colors.black87),
                        strong: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
      children: [
        _buildWelcomeCard(context), // Name updated inside
        const SizedBox(height: 25),
        
        _buildDailyTestCard(context),
        const SizedBox(height: 20),
        
        Row(
          children: [
            Expanded(child: _buildModernCustomTestCard()),
            const SizedBox(width: 15),
            Expanded(child: _buildModernNotesCard()),
          ],
        ),

        const SizedBox(height: 20),

        // 🔥 NEW AI ANALYSIS BUTTON (Placed Here)
        _buildAiAnalysisCard(),

        const SizedBox(height: 30),

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

  // ✨ NEW MODERN AI BUTTON
  Widget _buildAiAnalysisCard() {
    return Container(
      width: double.infinity,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        // Dark premium gradient
        gradient: const LinearGradient(
          colors: [Color(0xFF232526), Color(0xFF414345)], 
          begin: Alignment.centerLeft, end: Alignment.centerRight
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _onAiAnalyzePressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                // Glowing Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.3),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.purpleAccent.withOpacity(0.5))
                  ),
                  child: const Icon(Icons.psychology, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 15),
                // Text Content
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Text("Analysis By AI", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          SizedBox(width: 5),
                          Icon(Icons.auto_awesome, color: Colors.amber, size: 16) // Sparkle
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Check your weak & strong areas", 
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Arrow
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- EXISTING WIDGETS ---

  Widget _buildWelcomeCard(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 👋 Dynamic Name Here
            Text('Hello, $_displayName 👋', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
            const SizedBox(height: 5),
            const Text('Let\'s Crack It!', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 24)),
          ],
        ),
        
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('notifications').snapshots(),
          builder: (context, snapshot) {
             // ... (Notification logic same as before) ...
             return CircleAvatar(
                radius: 25, backgroundColor: Colors.grey[200],
                child: IconButton(icon: const Icon(Icons.notifications_none, color: Colors.black), onPressed: () => context.push('/notifications')),
              );
          },
        ),
      ],
    );
  }

  Widget _buildModernCustomTestCard() {
    return _buildCard(
      title: "Create\nCustom Test", subtitle: "By Topic",
      icon: Icons.auto_awesome, 
      colors: [const Color(0xFF6A11CB), const Color(0xFF2575FC)],
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TestGeneratorScreen())),
    );
  }

  Widget _buildModernNotesCard() {
    return _buildCard(
      title: "Quick\nNotes", subtitle: "Read PDF",
      icon: Icons.menu_book_rounded, 
      colors: [const Color(0xFFFF512F), const Color(0xFFF09819)],
      onTap: () => context.push('/public-notes'),
    );
  }

  // Generic Helper for Grid Cards
  Widget _buildCard({required String title, required String subtitle, required IconData icon, required List<Color> colors, required VoidCallback onTap}) {
    return Container(
      height: 170, 
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: colors[1].withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20), onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 24)),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold, height: 1.2)), const SizedBox(height: 5), Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12))]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDailyTestCard(BuildContext context) {
     final DateTime now = DateTime.now();
    final String todayDocId = DateFormat('yyyy-MM-dd').format(now);
    final String fullDate = DateFormat('dd MMMM yyyy').format(now);

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('DailyTests').doc(todayDocId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
            child: Row(children: [Icon(Icons.coffee, color: Colors.grey.shade400, size: 30), const SizedBox(width: 15), const Text("No Test for today yet!", style: TextStyle(color: Colors.grey))]),
          );
        }
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final subtitle = data['subtitle'] ?? "Daily Practice Test";
        final questionIds = List<String>.from(data['questionIds'] ?? []);
        
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: const LinearGradient(colors: [Color(0xFF11998e), Color(0xFF38ef7d)]), boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))]),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.calendar_today, color: Colors.white, size: 12), const SizedBox(width: 6), Text(fullDate, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))])),
                const SizedBox(height: 15),
                Text(subtitle, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                Text("${questionIds.length} Important Questions", style: const TextStyle(color: Colors.white70, fontSize: 15)),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF11998e), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () { AdManager.showInterstitialAd(() { context.push('/test-screen', extra: {'ids': questionIds}); }); }, child: const Text("Start Today's Test", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))))
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTestSeriesSection(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('testSeriesHome').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Text("No series available.");
        final seriesList = snapshot.data!.docs;
        return GridView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 0.85),
          itemCount: seriesList.length,
          itemBuilder: (context, index) {
            final data = seriesList[index].data() as Map<String, dynamic>;
            final title = data['title'] ?? "Series";
            final category = data['category'] ?? "Exam";
            Color accentColor = index % 2 == 0 ? Colors.purple : Colors.indigo;
            Color iconBg = index % 2 == 0 ? Colors.purple.shade50 : Colors.indigo.shade50;
            return Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 5, offset: const Offset(0, 3))]),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () { if (data['type'] == 'subject') { context.push('/subject-list', extra: {'seriesId': seriesList[index].id, 'seriesTitle': title}); } else { context.push('/test-list', extra: {'seriesId': seriesList[index].id, 'subjectId': 'default', 'subjectTitle': title}); } },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(height: 45, width: 45, decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.menu_book, color: accentColor)), const Spacer(), Text(category.toUpperCase(), style: TextStyle(color: Colors.grey[500], fontSize: 10, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 8), Row(children: [Text("View All", style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(width: 4), Icon(Icons.arrow_forward_rounded, size: 14, color: accentColor)])]),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
