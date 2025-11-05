import 'package:flutter/material.dart'; // ✅ YEH HAI ASLI FIX
import 'package:go_router/go_router.dart';

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
        _buildActionCard(
          context: context,
          icon: Icons.calendar_month_outlined,
          title: 'Schedules',
          subtitle: 'View daily schedules and updates',
          color: Colors.teal,
          onTap: () => context.go('/schedules'), // ✅ 'go' ka istemal
        ),
        const SizedBox(height: 16),
        _buildActionCard(
          context: context,
          icon: Icons.note_alt_outlined,
          title: 'Notes',
          subtitle: 'Read subject-wise short notes',
          color: Colors.orange,
          onTap: () => context.go('/public-notes'), // ✅ 'go' ka istemal
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
    required Color color,
    required VoidCallback onTap,
  }) {
    // Dark Mode ke liye icon ka color theek kiya
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
