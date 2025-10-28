import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:exambeing/navigation/app_router.dart';
import 'package:exambeing/firebase_options.dart'; // ✅ सही import
import 'package:google_fonts/google_fonts.dart';

// ⬇️===== NAYE IMPORTS =====⬇️
import 'package:provider/provider.dart';
import 'package:exambeing/services/theme_provider.dart'; // Hamari ThemeProvider file
// ⬆️=======================⬆️

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Firebase Initialize karo
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ⬇️===== YEH HAI NAYA CODE (ThemeProvider Ko Add Karne Ke Liye) =====⬇️
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(), // ThemeProvider ko create karo
      child: const ExambeingApp(), // Aur ExambeingApp ko uske andar rakho
    ),
  );
  // ⬆️================================================================⬆️
}

class ExambeingApp extends StatelessWidget {
  const ExambeingApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ⬇️===== YEH HAIN NAYI THEME DEFINITIONS =====⬇️
    final baseTextTheme = Theme.of(context).textTheme;

    // --- Light Theme ---
    final lightTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: Brightness.light, // Light Mode
      ),
      scaffoldBackgroundColor: const Color(0xFFF8F9FA), // Light background
      textTheme: GoogleFonts.poppinsTextTheme(baseTextTheme).apply(bodyColor: Colors.black87), // Light text
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white, // Light AppBar
        foregroundColor: Colors.black87, // Light Icons/Text
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
        color: Colors.white, // Light Card
        surfaceTintColor: Colors.white, // Prevent yellow tint on white cards
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
        backgroundColor: Colors.white, // Light Nav Bar
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
      ),
      // Add other light theme customizations if needed
    );

    // --- Dark Theme ---
    final darkTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: Brightness.dark, // Dark Mode
      ),
      scaffoldBackgroundColor: const Color(0xFF121212), // Dark background
      textTheme: GoogleFonts.poppinsTextTheme(baseTextTheme).apply(bodyColor: Colors.white70), // Dark text
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E), // Dark AppBar
        foregroundColor: Colors.white70, // Dark Icons/Text
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
        color: const Color(0xFF1E1E1E), // Dark Card
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
        backgroundColor: Color(0xFF1E1E1E), // Dark Nav Bar
        selectedItemColor: Colors.deepPurpleAccent,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
      ),
       // Add other dark theme customizations if needed
    );
    // ⬆️============================================⬆️

    // ⬇️===== THEMEPROVIDER KA ISTEMAL KARO =====⬇️
    // Get the current theme mode from ThemeProvider
    final themeProvider = Provider.of<ThemeProvider>(context);
    // ⬆️=========================================⬆️

    return MaterialApp.router(
      title: 'Exambeing',
      // ⬇️===== THEME KO APPLY KARO =====⬇️
      theme: lightTheme,        // Light theme define karo
      darkTheme: darkTheme,       // Dark theme define karo
      themeMode: themeProvider.themeMode, // ThemeProvider se current mode lo
      // ⬆️=============================⬆️
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}
