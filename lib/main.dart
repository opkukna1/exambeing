import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:exambeing/navigation/app_router.dart'; // ✅ apna router import
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool firebaseReady = false;

  try {
    await Firebase.initializeApp();
    firebaseReady = true;
    debugPrint("✅ Firebase initialized successfully");
  } catch (e) {
    debugPrint("❌ Firebase initialization failed: $e");
  }

  runApp(MyApp(firebaseReady: firebaseReady));
}

class MyApp extends StatelessWidget {
  final bool firebaseReady;
  const MyApp({super.key, required this.firebaseReady});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Exambeing',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // 🔹 Agar Firebase sahi init nahi hua to simple HomeScreen dikha do
      home: firebaseReady ? const AppStartWrapper() : const FirebaseErrorScreen(),
    );
  }
}

class AppStartWrapper extends StatelessWidget {
  const AppStartWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // 🔹 Agar user login hai to HomeScreen, warna LoginHubScreen
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return const HomeScreenSafe(); // Custom safe version
    } else {
      return const LoginScreenSafe(); // Custom safe version
    }
  }
}

class FirebaseErrorScreen extends StatelessWidget {
  const FirebaseErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          '⚠️ Firebase not initialized.\nApp running in offline mode.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class HomeScreenSafe extends StatelessWidget {
  const HomeScreenSafe({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: AppBar(title: Text("Exambeing Home")),
      body: Center(child: Text("✅ Home Screen Loaded")),
    );
  }
}

class LoginScreenSafe extends StatelessWidget {
  const LoginScreenSafe({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: AppBar(title: Text("Exambeing Login")),
      body: Center(child: Text("🔐 Please log in")),
    );
  }
}
