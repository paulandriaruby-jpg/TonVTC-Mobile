import 'package:flutter/material.dart';

// Couleurs du site (palette hellopro) : bleu de marque, orange pour l'action principale, texte marine.
class AppColors {
  static const brand = Color(0xFF3353FF);
  static const brandSoft = Color(0xFFF5F6FF);
  static const accent = Color(0xFFFB5607);
  static const accentSoft = Color(0xFFFFF5F0);
  static const ink = Color(0xFF041325);
  static const muted = Color(0xFF5F6B7A);
  static const surface = Color(0xFFF0F2F5);
  static const line = Color(0xFFE9E9E9);
  static const success = Color(0xFF02896C);
  static const successSoft = Color(0xFFDCFFF7);
  static const danger = Color(0xFFEA1F38);
  static const dangerSoft = Color(0xFFFEF1F3);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.brand, primary: AppColors.brand, secondary: AppColors.accent, surface: Colors.white);
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.surface,
    appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: AppColors.ink, elevation: 0, scrolledUnderElevation: 0.5),
    cardTheme: CardThemeData(color: Colors.white, elevation: 0, margin: EdgeInsets.zero, shape: shape),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: shape, textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: shape)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.line)),
    ),
    navigationBarTheme: const NavigationBarThemeData(backgroundColor: Colors.white, indicatorColor: AppColors.brandSoft),
  );
}
