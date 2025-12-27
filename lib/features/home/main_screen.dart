import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:exambeing/services/auth_service.dart';

// ✅ IMPORT ADMIN & MODERATOR SCREENS
import 'package:exambeing/features/admin/screens/manage_moderator_screens.dart';
import 'package:exambeing/features/moderator/screens/moderator_dashboard_screen.dart';

// ✅ IMPORT FULL SCREEN WIDGETS
import 'package:exambeing/features/notes/screens/my_notes_screen.dart'; 
import 'package:exambeing/features/tools/screens/pomodoro_screen.dart';
import 'package:exambeing/features/tools/screens/todo_list_screen.dart';
import 'package:exambeing/features/tools/screens/timetable_screen.dart';

class MainScreen extends StatefulWidget {
  final Widget child;
  const MainScreen({super.key, required this.child});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  DateTime? lastPressed;

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/test-series')) return 1;
    if (location.startsWith('/bookmarks_home')) return 2;
    if (location.startsWith('/profile')) return 3;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0: context.go('/'); break;
      case 1: context.go('/test-series'); break;
      case 2: context.go('/bookmarks_home'); break;
      case 3: context.go('/profile'); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    int selectedIndex = _calculateSelectedIndex(context);

    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) {
        if (didPop) return;
        final now = DateTime.now();
        const maxDuration = Duration(seconds: 2);
        final isWarning = lastPressed == null || now.difference(lastPressed!) > maxDuration;

        if (isWarning) {
          lastPressed = DateTime.now();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Press back again to exit'), duration: maxDuration),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        extendBody: false, 
        
        appBar: AppBar(
          title: Image.asset('assets/logo.png', height: 40),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        
        drawer: const AppDrawer(),
        
        body: widget.child,

        bottomNavigationBar: Container(
          color: Colors.transparent,
          child: SafeArea(
            child: Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(35),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 10)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(Icons.home_rounded, "Home", 0, selectedIndex),
                  _buildNavItem(Icons.menu_book_rounded, "Tests", 1, selectedIndex),
                  _buildNavItem(Icons.auto_stories_rounded, "Self Study", 2, selectedIndex),
                  _buildNavItem(Icons.person_rounded, "Profile", 3, selectedIndex),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, int selectedIndex) {
    bool isSelected = index == selectedIndex;
    return GestureDetector(
      onTap: () => _onItemTapped(index, context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuad,
        padding: isSelected ? const EdgeInsets.symmetric(horizontal: 20, vertical: 10) : const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepPurple : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.grey.shade400, size: 26),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ]
          ],
        ),
      ),
    );
  }
}

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final authService = AuthService();
    
    final bool isAdmin = user?.email?.toLowerCase().trim() == "opsiddh42@gmail.com";

    return Drawer(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(topRight: Radius.circular(20), bottomRight: Radius.circular(20))),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6A11CB), Color(0xFF2575FC)], 
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(bottomRight: Radius.circular(30)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  backgroundImage: (user?.photoURL != null) ? NetworkImage(user!.photoURL!) : null,
                  child: (user?.photoURL == null) ? const Icon(Icons.person, size: 30, color: Colors.deepPurple) : null,
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ?? "Guest User",
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        user?.email ?? "Welcome!",
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              children: [
                _buildDrawerItem(context, Icons.home_rounded, "Home", () => context.go('/')),
                _buildDrawerItem(context, Icons.auto_stories_rounded, "Self Study", () => context.go('/bookmarks_home')),
                
                // 🔥 FIX: 'const' removed from MyNotesScreen
                _buildDrawerItem(context, Icons.note_alt_rounded, "My Notes", () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => MyNotesScreen()));
                }),

                const SizedBox(height: 15),
                _buildSectionTitle("Study Tools"),
                
                // 🔥 FIX: 'const' removed from PomodoroScreen
                _buildDrawerItem(context, Icons.timer_rounded, "Pomodoro Timer", () {
                   Navigator.push(context, MaterialPageRoute(builder: (context) => PomodoroScreen()));
                }),
                
                // 🔥 FIX: 'const' removed from ToDoListScreen
                _buildDrawerItem(context, Icons.check_circle_rounded, "To-Do List", () {
                   Navigator.push(context, MaterialPageRoute(builder: (context) => ToDoListScreen()));
                }),
                
                // 🔥 FIX: 'const' removed from TimetableScreen
                _buildDrawerItem(context, Icons.calendar_month_rounded, "My Timetable", () {
                   Navigator.push(context, MaterialPageRoute(builder: (context) => TimetableScreen()));
                }),

                if (user != null)
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('moderator_assignments')
                        .where('moderatorEmail', isEqualTo: user.email?.trim().toLowerCase())
                        .limit(1)
                        .snapshots(),
                    builder: (context, snapshot) {
                      bool isModerator = snapshot.hasData && snapshot.data!.docs.isNotEmpty;

                      if (isAdmin || isModerator) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 15),
                            _buildSectionTitle("Management Panel 🛡️"),

                            if (isAdmin)
                              _buildDrawerItem(
                                context, 
                                Icons.admin_panel_settings_rounded, 
                                "Manage Moderators", 
                                () {
                                  // 🔥 const is likely safe here as I wrote that file, but removing to be absolutely safe
                                  Navigator.push(context, MaterialPageRoute(builder: (c) => ManageModeratorScreen()));
                                },
                                isSpecial: true,
                                specialColor: Colors.redAccent
                              ),

                            if (isAdmin || isModerator)
                              _buildDrawerItem(
                                context, 
                                Icons.analytics_rounded, 
                                "Moderator Dashboard", 
                                () {
                                  // 🔥 const is likely safe here as I wrote that file, but removing to be absolutely safe
                                  Navigator.push(context, MaterialPageRoute(builder: (c) => ModeratorDashboardScreen()));
                                },
                                isSpecial: true,
                                specialColor: Colors.deepPurple
                              ),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.all(10),
            child: _buildDrawerItem(
              context, 
              user != null ? Icons.logout_rounded : Icons.login_rounded, 
              user != null ? "Logout" : "Login", 
              () async {
                if (user != null) {
                  await authService.signOut();
                  if(context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Logged out.")));
                    context.go('/login-hub');
                  }
                } else {
                  context.go('/login-hub');
                }
              },
              isLogout: true
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(BuildContext context, IconData icon, String title, VoidCallback onTap, {bool isSpecial = false, Color? specialColor, bool isLogout = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSpecial ? (specialColor ?? Colors.blue).withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isLogout 
               ? Colors.grey.shade200 
               : (isSpecial ? (specialColor ?? Colors.blue).withOpacity(0.2) : Colors.deepPurple.shade50),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon, 
            color: isLogout 
               ? Colors.grey 
               : (isSpecial ? (specialColor ?? Colors.blue) : Colors.deepPurple), 
            size: 20
          ),
        ),
        title: Text(
          title, 
          style: TextStyle(
            fontWeight: isSpecial ? FontWeight.bold : FontWeight.w500,
            color: isSpecial ? (specialColor ?? Colors.black) : Colors.black87,
            fontSize: 15
          )
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
        onTap: () {
          Navigator.pop(context); 
          onTap(); 
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        hoverColor: Colors.deepPurple.withOpacity(0.05),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 1.2),
      ),
    );
  }
}
