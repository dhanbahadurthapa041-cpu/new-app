import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF008080); // Teal
  static const Color secondaryColor = Color(0xFFFF7F50); // Coral
  static const Color backgroundColor = Color(0xFFF5F5F5);

  static ThemeData get lightTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: secondaryColor,
        background: backgroundColor,
      ),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      useMaterial3: true,
    );
  }
}
