import 'package:flutter/material.dart';

abstract final class AppTheme {
  // Paleta de los mockups de SmartMarket.
  static const green = Color(0xFF2F5A27);
  static const lime = Color(0xFFA8DD84);
  static const background = Color(0xFFF4F6F0);
  static const tint = Color(0xFFEEF5E6);
  static const track = Color(0xFFE6E9E2);
  static const border = Color(0xFFE8EBE4);
  static const ink = Color(0xFF1C1F1A);
  static const muted = Color(0xFF6B7066);

  static const cardShadow = [
    BoxShadow(color: Color(0x14000000), blurRadius: 24, offset: Offset(0, 8)),
  ];

  static final light = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: green,
      primary: green,
      secondary: lime,
      surface: Colors.white,
      onSurface: ink,
    ),
    scaffoldBackgroundColor: background,
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      foregroundColor: ink,
      centerTitle: false,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: lime,
        foregroundColor: ink,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: ink,
        side: const BorderSide(color: border),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: lime,
      foregroundColor: ink,
    ),
  );
}
