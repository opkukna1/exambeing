// 1. ⬇️ FIX: Path 'package:flutter/material.dart' hona chahiye
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

// 2. ⬇️ FIX: Path 'app_router.dart' hona chahiye
import 'router.dart'; // Apni router file ko import karein

// Agar aapne FlutterFire CLI ka istemal kiya hai, to ise uncomment karein
// import 'firebase_options.dart';

void main() async {
  // Flutter Engine ko ready karta hai
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase ko start karta hai
  try {
    await Firebase.initializeApp(
      // Agar 'firebase_options.dart' file hai to 'options' ka istemal karein
      // options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Agar Firebase initialize nahi hua to error print karein
    debugPrint("Firebase initialization failed: $e");
  }

  // App ko run karta hai
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Agar Provider use nahi kar rahe hain:
    return MaterialApp.router(
      title: 'Exambeing',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      routerConfig: router, // Aapka GoRouter config
    );
  }
}
