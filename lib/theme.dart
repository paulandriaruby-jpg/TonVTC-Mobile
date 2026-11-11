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
    // Boutons secondaires : bordure marquée, fond blanc, texte gras, même hauteur que le bouton principal.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: shape,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: AppColors.brand, shape: shape, textStyle: const TextStyle(fontWeight: FontWeight.w700))),
    dialogTheme: DialogThemeData(backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20)),
    chipTheme: ChipThemeData(labelStyle: const TextStyle(color: AppColors.ink), shape: shape),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.line)),
    ),
    // Arrondis de 8 px au plus partout (règle TonVTC) : Material 3 met 28 px aux feuilles du bas et une capsule à la
    // pastille de navigation par défaut.
    navigationBarTheme: NavigationBarThemeData(backgroundColor: Colors.white, indicatorColor: AppColors.brandSoft, indicatorShape: shape),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(8)))),
    elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(shape: shape)),
    floatingActionButtonTheme: FloatingActionButtonThemeData(shape: shape),
    segmentedButtonTheme: SegmentedButtonThemeData(style: SegmentedButton.styleFrom(shape: shape)),
  );
}
