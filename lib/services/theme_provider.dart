import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  // SharedPreferences key jahaan theme save hoga
  static const String _themePrefKey = 'themeMode';

  ThemeMode _themeMode = ThemeMode.light; // Default theme
  bool _isInitialized = false; // Check karne ke liye ki SharedPreferences load hua ya nahi

  ThemeProvider() {
    _loadTheme(); // App shuru hote hi saved theme load karo
  }

  ThemeMode get themeMode => _themeMode;

  // Saved theme ko SharedPreferences se load karo
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themePrefKey) ?? ThemeMode.light.index;
    _themeMode = ThemeMode.values[themeIndex];
    _isInitialized = true;
    notifyListeners(); // UI ko batao ki theme load ho gaya
  }

  // Nayi theme ko set karo aur SharedPreferences mein save karo
  Future<void> setTheme(ThemeMode themeMode) async {
    if (_themeMode == themeMode || !_isInitialized) return; // Agar same theme hai ya load nahi hua to kuchh na karo

    _themeMode = themeMode;
    notifyListeners(); // UI ko batao ki theme badal gaya

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themePrefKey, themeMode.index);
  }

  // Theme ko Light se Dark ya Dark se Light karo
  void toggleTheme() {
    setTheme(_themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light);
  }
}
