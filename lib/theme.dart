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
  // Bordure des champs (comme les champs du site).
  static const field = Color(0xFFCBD5E1);
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
    // Boutons secondaires (Refuser, Annuler, Itinéraire...) : bordure marquée, fond blanc, texte gras, même hauteur
    // que le bouton principal, pour ne pas faire "lien" à côté de lui.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: shape,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.field, width: 1.5),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    // Boutons texte (Ajouter, Mot de passe oublié...) : en bleu, gras, sur un léger fond au toucher.
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: AppColors.brand, shape: shape, textStyle: const TextStyle(fontWeight: FontWeight.w700))),
    // Fenêtres de confirmation : coins arrondis, boutons alignés à droite avec un espace.
    dialogTheme: DialogThemeData(backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20)),
    // Champs comme sur le site : label dans le champ au repos, sur la bordure au focus ou avec une valeur.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: const TextStyle(color: Color(0xFF64748B)),
      floatingLabelStyle: WidgetStateTextStyle.resolveWith((states) => TextStyle(
            color: states.contains(WidgetState.error) ? AppColors.danger : states.contains(WidgetState.focused) ? AppColors.brand : const Color(0xFF64748B),
            fontWeight: states.contains(WidgetState.focused) ? FontWeight.w600 : FontWeight.w400,
          )),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.field)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.field)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.brand, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.danger)),
    ),
    navigationBarTheme: const NavigationBarThemeData(backgroundColor: Colors.white, indicatorColor: AppColors.brandSoft),
  );
}
