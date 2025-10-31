import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:exambeing/navigation/app_router.dart';
import 'package:exambeing/firebase_options.dart'; // ✅ सही import
import 'package:google_fonts/google_fonts.dart';

import 'package:provider/provider.dart';
import 'package:exambeing/services/theme_provider.dart'; // Hamari ThemeProvider file

import 'package:google_mobile_ads/google_mobile_ads.dart';

// ⬇️===== NAYI SERVICE IMPORT =====⬇️
import 'package:exambeing/services/ad_service_provider.dart'; // Hamari Ad Service file
// ⬆️=============================⬆️

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Firebase Initialize karo
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // AdMob SDK ko initialize karo (bina 'await' ke)
  MobileAds.instance.initialize();

  // ⬇️===== YEH HAI NAYA MULTIPROVIDER CODE =====⬇️
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => AdServiceProvider()), // Ad Service ko register karo
      ],
      child: const ExambeingApp(),
    ),
  );
  // ⬆️========================================⬆️
}

class ExambeingApp extends StatelessWidget {
  const ExambeingApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTextTheme = Theme.of(context).textTheme;

    // --- Light Theme ---
    final lightTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      textTheme: GoogleFonts.poppinsTextTheme(baseTextTheme).apply(bodyColor: Colors.black87),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1.0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 18.0,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30.0),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
      ),
    );

    // --- Dark Theme ---
    final darkTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      textTheme: GoogleFonts.poppinsTextTheme(baseTextTheme).apply(bodyColor: Colors.white70),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E),
        foregroundColor: Colors.white70,
        elevation: 1.0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 18.0,
          fontWeight: FontWeight.w600,
          color: Colors.white70,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30.0),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF1E1E1E),
        selectedItemColor: Colors.deepPurpleAccent,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
      ),
    );
    
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp.router(
      title: 'Exambeing',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeProvider.themeMode,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}
