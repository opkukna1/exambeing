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
    return PopScope(
      canPop: false,
      // ✅ FIX: Added ignore comment for the overly strict lint rule
      // ignore: deprecated_member_use
      onPopInvoked: (bool didPop) {
        if (didPop) return;

        final now = DateTime.now();
        const maxDuration = Duration(seconds: 2);
        final isWarning = lastPressed == null || now.difference(lastPressed!) > maxDuration;

        if (isWarning) {
          lastPressed = DateTime.now();
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Press back again to exit'), duration: maxDuration),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Image.asset('assets/logo.png', height: 40),
        ),
        drawer: const AppDrawer(),
        body: widget.child,
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _calculateSelectedIndex(context),
          onTap: (index) => _onItemTapped(index, context),
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.menu_book_outlined), activeIcon: Icon(Icons.menu_book), label: 'Tests'),
            BottomNavigationBarItem(icon: Icon(Icons.bookmark_border), activeIcon: Icon(Icons.bookmark), label: 'Bookmarks'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

// Drawer's Code
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
              accountName: Text(user.displayName ?? 'No Name'),
              accountEmail: Text(user.email ?? 'No Email'),
              currentAccountPicture: CircleAvatar(
                backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                child: user.photoURL == null ? const Icon(Icons.person, size: 40) : null,
              ),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary),
            )
          else
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.grey.shade400),
              child: const Text('Guest User', style: TextStyle(color: Colors.white, fontSize: 24)),
            ),

          ListTile(leading: const Icon(Icons.home_outlined), title: const Text('Home'), onTap: () { Navigator.pop(context); context.go('/'); }),
          ListTile(leading: const Icon(Icons.bookmarks_outlined), title: const Text('Bookmarks'), onTap: () { Navigator.pop(context); context.go('/bookmarks_home'); }),
          ListTile(
            leading: const Icon(Icons.note_add_outlined),
            title: const Text('My Notes'),
            onTap: () {
              Navigator.pop(context);
              context.push('/my-notes');
            },
          ),
          
          const Divider(),
          if (user != null)
            ListTile(
              leading: const Icon(Icons.logout_outlined),
              title: const Text('Logout'),
              onTap: () async {
                await authService.signOut();
                // ✅ FIX: Changed to use context.mounted for the safety check
                if(context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Logged out.")));
                  context.go('/login-hub');
                }
              },
            )
          else
             ListTile(
              leading: const Icon(Icons.login),
              title: const Text('Login'),
              onTap: () => context.go('/login-hub'),
            ),
        ],
      ),
    );
  }
}
