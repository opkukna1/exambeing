import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:exambeing/services/auth_service.dart';

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
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/test-series');
        break;
      case 2:
        context.go('/bookmarks_home');
        break;
      case 3:
        context.go('/profile');
        break;
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
        // Background color thoda grey rakha hai taaki white bar pop kare
        backgroundColor: Colors.grey.shade50, 
        extendBody: true, // Body ko bottom bar ke piche jaane deta hai
        appBar: AppBar(
          title: Image.asset('assets/logo.png', height: 40),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        drawer: const AppDrawer(),
        body: widget.child,

        // ✨ MODERN FLOATING NAVIGATION BAR ✨
        bottomNavigationBar: SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 20), // Side aur Bottom se gap
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(35), // Capsule Shape
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
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
    );
  }

  // ✨ CUSTOM ANIMATED ITEM WIDGET
  Widget _buildNavItem(IconData icon, String label, int index, int selectedIndex) {
    bool isSelected = index == selectedIndex;
    
    return GestureDetector(
      onTap: () => _onItemTapped(index, context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuad,
        padding: isSelected 
            ? const EdgeInsets.symmetric(horizontal: 20, vertical: 10) 
            : const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepPurple : Colors.transparent, // Active Color
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey.shade400,
              size: 26,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}

// Drawer's Code (Same as before, bas Self Study update ke sath)
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final authService = AuthService();

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          if (user != null)
            UserAccountsDrawerHeader(
              accountName: Text(user.displayName ?? 'Student'),
              accountEmail: Text(user.email ?? ''),
              currentAccountPicture: CircleAvatar(
                backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                child: user.photoURL == null ? const Icon(Icons.person, size: 40) : null,
              ),
              decoration: BoxDecoration(color: Colors.deepPurple), // Consistent Theme
            )
          else
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.grey.shade400),
              child: const Text('Guest User', style: TextStyle(color: Colors.white, fontSize: 24)),
            ),

          ListTile(leading: const Icon(Icons.home_outlined), title: const Text('Home'), onTap: () { Navigator.pop(context); context.go('/'); }),
          
          // Self Study Link
          ListTile(
            leading: const Icon(Icons.auto_stories_outlined), 
            title: const Text('Self Study'), 
            onTap: () { 
              Navigator.pop(context); 
              context.go('/bookmarks_home'); 
            }
          ),

          ListTile(
            leading: const Icon(Icons.note_add_outlined),
            title: const Text('My Notes'),
            onTap: () {
              Navigator.pop(context);
              context.push('/my-notes');
            },
          ),
          
          const Divider(),
          Padding(
            padding: const EdgeInsets.only(left: 16.0, top: 16.0, bottom: 8.0),
            child: Text('Study Tools', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
          ),
          ListTile(leading: const Icon(Icons.timer_outlined), title: const Text('Pomodoro Timer'), onTap: () { Navigator.pop(context); context.push('/pomodoro'); }),
          ListTile(leading: const Icon(Icons.check_circle_outline), title: const Text('To-Do List'), onTap: () { Navigator.pop(context); context.push('/todo-list'); }),
          ListTile(leading: const Icon(Icons.calendar_month_outlined), title: const Text('My Timetable'), onTap: () { Navigator.pop(context); context.push('/timetable'); }),
          
          const Divider(),
          if (user != null)
            ListTile(
              leading: const Icon(Icons.logout_outlined),
              title: const Text('Logout'),
              onTap: () async {
                await authService.signOut();
                if(context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Logged out.")));
                  context.go('/login-hub');
                }
              },
            )
          else
             ListTile(leading: const Icon(Icons.login), title: const Text('Login'), onTap: () => context.go('/login-hub')),
        ],
      ),
    );
  }
}
