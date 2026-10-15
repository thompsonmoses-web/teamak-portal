import 'package:flutter/material.dart';

/// Brand palette for Teamak Global Solution Limited, styled after the
/// Value Circle Africa design language: emerald primary, cyan accent,
/// amber-gold highlights on a mint-white surface, pill buttons and
/// generously rounded cards.
class TeamakColors {
  /// Emerald primary (`--ap-primary`).
  static const Color primary = Color(0xFF22C55E);

  static const Color primaryLight = Color(0xFF16A34A);
  static const Color primaryDark = Color(0xFF15803D);

  /// Cyan accent (`--ap-accent`).
  static const Color accent = Color(0xFF06B6D4);
  static const Color accentDark = Color(0xFF0891B2);

  /// Amber-gold highlight (`--ap-gold`).
  static const Color gold = Color(0xFFD97706);
  static const Color goldLight = Color(0xFFB45309);

  static const Color ink = Color(0xFF111827);
  static const Color subtle = Color(0xFF4B5563);
  static const Color dim = Color(0xFF9CA3AF);

  /// Mint page background (`--ap-bg`), with two deeper tints for bands.
  static const Color surface = Color(0xFFF0FDF4);
  static const Color surface2 = Color(0xFFECFDF5);
  static const Color surface3 = Color(0xFFDCFCE7);

  static const Color border = Color(0x17000000); // rgba(0,0,0,.09)
  static const Color borderStrong = Color(0x29000000);
  static const Color danger = Color(0xFFDC2626);

  /// `--ap-grad-primary`: 135° emerald sweep used on buttons and banners.
  static const LinearGradient gradPrimary = LinearGradient(
    colors: <Color>[primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// `--ap-grad-gold`: amber→coral sweep for emphasis.
  static const LinearGradient gradGold = LinearGradient(
    colors: <Color>[Color(0xFFF59E0B), Color(0xFFEF4444)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// `--ap-grad-success`: emerald→cyan sweep for hero/CTA tints.
  static const LinearGradient gradSuccess = LinearGradient(
    colors: <Color>[Color(0xFF10B981), accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: TeamakColors.primary,
    primary: TeamakColors.primary,
    secondary: TeamakColors.accent,
    error: TeamakColors.danger,
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: TeamakColors.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white.withValues(alpha: 0.92),
      surfaceTintColor: Colors.transparent,
      foregroundColor: TeamakColors.ink,
      elevation: 0,
      centerTitle: false,
      shape: const Border(
        bottom: BorderSide(color: TeamakColors.border),
      ),
      titleTextStyle: const TextStyle(
        color: TeamakColors.ink,
        fontWeight: FontWeight.w800,
        fontSize: 16,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: TeamakColors.borderStrong),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: TeamakColors.borderStrong),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: TeamakColors.primary, width: 1.8),
      ),
      labelStyle: const TextStyle(color: TeamakColors.ink),
      hintStyle: const TextStyle(color: TeamakColors.dim),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shadowColor: TeamakColors.primary.withValues(alpha: 0.18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: TeamakColors.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: TeamakColors.primaryLight,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 17),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        // Pill buttons, per the reference design.
        shape: const StadiumBorder(),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: TeamakColors.primaryDark,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        side: const BorderSide(color: TeamakColors.borderStrong),
        shape: const StadiumBorder(),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: TeamakColors.primaryDark,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      linearTrackColor: TeamakColors.surface3,
      color: TeamakColors.primary,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: TeamakColors.ink,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerTheme:
        const DividerThemeData(color: TeamakColors.border, space: 1),
  );
}
