import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Pastel Palette
  static const Color mintGreen = Color(0xFFA8E6CF);
  static const Color palePink = Color(0xFFFFD3B6);
  static const Color mutedLavender = Color(0xFFE6E6FA); 
  static const Color babyBlue = Color(0xFFD4F1F4);
  static const Color darkText = Color(0xFF2C3E50);
  static const Color offWhite = Color(0xFFFAF9F6);

  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: mintGreen,
      scaffoldBackgroundColor: offWhite,
      colorScheme: const ColorScheme.light(
        primary: mintGreen,
        secondary: palePink,
        surface: Colors.white,
        background: offWhite,
        error: Colors.redAccent,
        onPrimary: darkText,
        onSecondary: darkText,
        onSurface: darkText,
        onBackground: darkText,
      ),
      textTheme: GoogleFonts.interTextTheme().apply(
        bodyColor: darkText,
        displayColor: darkText,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: babyBlue,
          foregroundColor: darkText,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: mintGreen,
        elevation: 0,
        iconTheme: IconThemeData(color: darkText),
        titleTextStyle: TextStyle(
          color: darkText,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: mintGreen, width: 2),
        ),
        labelStyle: TextStyle(color: Colors.grey.shade700),
      ),
    );
  }
}
