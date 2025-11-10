import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 👈 Naya Import
import 'package:intl/intl.dart'; // 👈 Naya Import

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildWelcomeCard(context),
        const SizedBox(height: 24),
        
        // 1. SCHEDULES HATA KAR DAILY TEST ADD KAR DIYA HAI
        _buildDailyTestCard(context),
        const SizedBox(height: 24),

        // 2. "NOTES" WALA CARD WAISE HI RAKHA HAI
        _buildActionCard(
          context: context,
          icon: Icons.note_alt_outlined,
          title: 'Notes',
          subtitle: 'Read subject-wise short notes',
          color: Colors.orange,
          onTap: () => context.go('/public-notes'),
        ),
        const SizedBox(height: 24),

        // 3. NAYA "TEST SERIES" SECTION ADD KIYA HAI
        _buildTestSeriesSection(context),
      ],
    );
  }

  // YE NAYA WIDGET HAI (DAILY TEST KE LIYE)
  Widget _buildDailyTestCard(BuildContext context) {
    // Aaj ki tareekh YYYY-MM-DD format mein (jaise: 2025-11-10)
    final String todayDocId = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return FutureBuilder<DocumentSnapshot>(
      // Firebase se sirf aaj ka test document fetch karo
      future: FirebaseFirestore.instance
          .collection('DailyTests')
          .doc(todayDocId)
          .get(),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Agar test nahi mila (aapne manually add nahi kiya)
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Card(
            margin: const EdgeInsets.all(0), // No extra margin
            child: const Padding(
              padding: EdgeInsets.all(20.0),
              child: Center(
                child: Text(
                  "Today's test is not available yet.",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          );
        }

        // Test mil gaya, data nikalo
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final title = data['title'] ?? "Today's Target";
        final subtitle = data['subtitle'] ?? "Daily Practice Test";
        final questionIds = List<String>.from(data['questionIds'] ?? []);
        
        // Screenshot jaisa Card
        return Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          margin: const EdgeInsets.all(0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  "${questionIds.length} Questions Practice", // 20 Questions Practice
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                    ),
                    onPressed: () {
                      // Test Screen par question IDs ki list bhej do
                      context.go('/test-screen', extra: {'ids': questionIds});
                    },
                    child: const Text(
                      "Start Test >",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  // YE BHI NAYA WIDGET HAI (TEST SERIES GRID KE LIYE)
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
          stream: FirebaseFirestore.instance.collection('TestSeries').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text("No test series available right now."));
            }

            final seriesList = snapshot.data!.docs;

            return GridView.builder(
              shrinkWrap: true, // Zaroori hai ListView ke andar
              physics: const NeverScrollableScrollPhysics(), // Zaroori hai ListView ke andar
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // Ek row mein 2 items
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.9, // Card ki height/width ratio
              ),
              itemCount: seriesList.length,
              itemBuilder: (context, index) {
                final series = seriesList[index];
                final data = series.data() as Map<String, dynamic>;
                
                final title = data['title'] ?? "N/A";
                final subtitle = data['subtitle'] ?? "View Tests";
                final category = data['category'] ?? "Exam"; // Jaise "RSSB"
                final color = data['colorCode'] != null 
                    ? Color(int.parse(data['colorCode'])) 
                    : Colors.teal.shade50; // Default color

                return Card(
                  color: color.withOpacity(0.3),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(15),
                    onTap: () {
                      // Test List Page par bhej do series ki ID ke saath
                      context.go('/test-list', extra: series.id);
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


  // --- AAPKE PURANE WIDGETS (KOI CHANGE NAHI) ---

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
