import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

// ⚠️ FIX: Yeh hai aapka sahi router path
import 'package:exambeing/navigation/app_router.dart'; 

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
      routerConfig: router, // Ab yeh 'router' variable mil jayega
    );
  }
}
