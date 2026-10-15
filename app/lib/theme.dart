import 'package:flutter/material.dart';

/// Brand colours for Teamak Global Solution Limited (blue + gold from logo).
///
/// The palette is the original Teamak code; the extra tokens (light/dark
/// siblings, tints, borders, gradients) exist so the Value Circle-style
/// layout can be painted in the brand colours.
class TeamakColors {
  /// Brand blue (`#0D47A1`).
  static const Color primary = Color(0xFF0D47A1);

  static const Color primaryLight = Color(0xFF1565C0);
  static const Color primaryDark = Color(0xFF072E68);

  /// Brand gold (`#F4A81D`).
  static const Color accent = Color(0xFFF4A81D);
  static const Color accentDark = Color(0xFFC98A12);

  static const Color gold = Color(0xFFF4A81D);
  static const Color goldLight = Color(0xFFC98610);

  static const Color ink = Color(0xFF0E1B33);
  static const Color subtle = Color(0xFF5C6B84);
  static const Color dim = Color(0xFF8A97AD);

  /// Page background, with two deeper blue tints for bands.
  static const Color surface = Color(0xFFF5F7FB);
  static const Color surface2 = Color(0xFFEEF2F9);
  static const Color surface3 = Color(0xFFDCE4F2);

  static const Color border = Color(0xFFE4E9F2);
  static const Color borderStrong = Color(0xFFC6CEE0);
  static const Color danger = Color(0xFFDC2626);

  /// 135° blue sweep used on buttons and banners.
  static const LinearGradient gradPrimary = LinearGradient(
    colors: <Color>[primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Gold→deep-orange sweep for emphasis.
  static const LinearGradient gradGold = LinearGradient(
    colors: <Color>[Color(0xFFF4A81D), Color(0xFFEF6C00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Blue→gold sweep for hero/CTA tints.
  static const LinearGradient gradSuccess = LinearGradient(
    colors: <Color>[primaryLight, accent],
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
