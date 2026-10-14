import 'package:flutter/material.dart';

/// Brand colours for Teamak Global Solution Limited (blue + gold from logo).
class TeamakColors {
  static const Color primary = Color(0xFF0D47A1);
  static const Color primaryDark = Color(0xFF072E68);
  static const Color accent = Color(0xFFF4A81D);
  static const Color ink = Color(0xFF0E1B33);
  static const Color subtle = Color(0xFF5C6B84);
  static const Color surface = Color(0xFFF5F7FB);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: TeamakColors.primary,
    primary: TeamakColors.primary,
    secondary: TeamakColors.accent,
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: TeamakColors.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: TeamakColors.ink,
      elevation: 0,
      centerTitle: false,
      shape: const Border(
        bottom: BorderSide(color: TeamakColors.accent, width: 1.4),
      ),
      titleTextStyle: const TextStyle(
        color: TeamakColors.ink,
        fontWeight: FontWeight.w700,
        fontSize: 16,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD9DEE7)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD9DEE7)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: TeamakColors.primary, width: 1.8),
      ),
      labelStyle: const TextStyle(color: TeamakColors.ink),
      hintStyle: const TextStyle(color: TeamakColors.subtle),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shadowColor: TeamakColors.primary.withValues(alpha: 0.18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE4E9F2)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 17),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
        side: const BorderSide(color: Color(0xFFC6CEE0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: TeamakColors.primary,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      linearTrackColor: Color(0xFFE4E9F2),
      color: TeamakColors.primary,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: TeamakColors.ink,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFFE4E9F2), space: 1),
  );
}
