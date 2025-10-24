import 'package.flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart'; // Provider ke liye (agar use kar rahe hain)
import 'app_router.dart'; // ⚠️ IMPORTANT: Apni router file ko import karein

// Agar aapne FlutterFire CLI ka istemal kiya hai, to ise uncomment karein
// import 'firebase_options.dart'; 

void main() async {
  // 1. Flutter Engine ko ready karta hai
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Firebase ko start karta hai (yahi crash rokega)
  try {
    await Firebase.initializeApp(
      // Agar 'firebase_options.dart' file hai to 'options' ka istemal karein
      // options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Agar Firebase initialize nahi hua to error print karein
    debugPrint("Firebase initialization failed: $e");
    // Yahan ek error screen dikha sakte hain, par abhi ke liye bas print karte hain
  }

  // 3. App ko run karta hai
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Agar aap Provider ka istemal kar rahe hain, to use yahan setup karein
    // return MultiProvider(
    //   providers: [
    //     // Apne providers yahan daalein
    //     // ChangeNotifierProvider(create: (_) => MyProvider()),
    //   ],
    //   child: MaterialApp.router(
    //     title: 'Exambeing',
    //     debugShowCheckedModeBanner: false,
    //     theme: ThemeData(
    //       primarySwatch: Colors.blue,
    //       visualDensity: VisualDensity.adaptivePlatformDensity,
    //     ),
    //     routerConfig: router, // Aapka GoRouter config
    //   ),
    // );

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
