import 'package:flutter/material.dart';

class AppTheme {
  /// Builds the light theme with soft, harmonious colors.
  static ThemeData buildLightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF6C5CE7), // Soft purple
        secondary: Color(0xFF00B894), // Soft teal
        surface: Color(0xFFF5F5F5), // Light gray
        onSurface: Color(0xFF2D3436), // Dark gray for text
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF6C5CE7),
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3436)),
        displayMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3436)),
        bodyLarge: TextStyle(fontSize: 16, color: Color(0xFF2D3436)),
        bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF2D3436)),
        labelLarge: TextStyle(
            fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }

  /// Builds the dark theme with soft, harmonious colors.
  static ThemeData buildDarkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF6C5CE7), // Soft purple
        secondary: Color(0xFF00B894), // Soft teal
        surface: Color(0xFF2D3436), // Dark gray
        onSurface: Color(0xFFF5F5F5), // Light gray for text
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF2D3436),
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 4,
        color: const Color(0xFF2D3436),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFFF5F5F5)),
        displayMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFFF5F5F5)),
        bodyLarge: TextStyle(fontSize: 16, color: Color(0xFFF5F5F5)),
        bodyMedium: TextStyle(fontSize: 14, color: Color(0xFFF5F5F5)),
        labelLarge: TextStyle(
            fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }
}
