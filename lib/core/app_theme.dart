import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central design system implementing DESIGN.md "The Luminescent Vault"
/// aesthetic with full Dark & Light theme support.
class AppTheme {
  AppTheme._();

  // ──────────────────────────────────────────────
  // Color Tokens (from DESIGN.md §2)
  // ──────────────────────────────────────────────

  // Brand / Primary
  static const Color primary = Color(0xFF5A51C4);
  static const Color primaryContainer = Color(0xFF7B6FE0);

  // Secondary
  static const Color secondaryDark = Color(0xFFB6A4F3);
  static const Color secondaryLight = Color(0xFF6E58B1);

  // Tertiary
  static const Color tertiary = Color(0xFF4E6DB4);

  // Dark Theme Surfaces
  static const Color darkSurface = Color(0xFF131319);
  static const Color darkSurfaceContainer = Color(0xFF1F1F25);
  static const Color darkSurfaceContainerHigh = Color(0xFF2A2A32);
  static const Color surface = darkSurface; // Compatibility

  // Light Theme Surfaces
  static const Color lightSurface = Color(0xFFFCFBFF);
  static const Color lightSurfaceContainer = Color(0xFFF2F1F9);
  static const Color lightSurfaceContainerHigh = Color(0xFFE8E7F0);

  // Text
  static const Color darkOnSurface = Color(0xFFFFFFFF);
  static const Color darkOnSurfaceVariant = Color(0xFFC8C4D5);
  static const Color lightOnSurface = Color(0xFF131319);
  static const Color lightOnSurfaceVariant = Color(0xFF5A5A66);

  // Status Accents (Neon Status Visibility)
  static const Color neonGreenDark = Color(0xFF00FF85);
  static const Color neonGreenLight = Color(0xFF00B35D);
  static const Color amber = Color(0xFFFFB800);

  // ──────────────────────────────────────────────
  // Shape Tokens (from DESIGN.md §4)
  // ──────────────────────────────────────────────

  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0; // ROUND_TWELVE
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 24.0;

  // Minimum touch target (Fitts's Law — DESIGN.md §4)
  static const double minTouchTarget = 48.0;

  // ──────────────────────────────────────────────
  // Typography (Inter — DESIGN.md §3)
  // ──────────────────────────────────────────────

  static TextTheme _buildTextTheme(TextTheme base, Color onSurface, Color onSurfaceVariant) {
    return GoogleFonts.interTextTheme(base).copyWith(
      displayLarge: GoogleFonts.inter(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8, // -2% letter spacing
        color: onSurface,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.64,
        color: onSurface,
      ),
      headlineLarge: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: onSurface,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: onSurface,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16, // Min 16sp — Radical Accessibility
        fontWeight: FontWeight.w400,
        color: onSurfaceVariant,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 16, // Never go below 16sp
        fontWeight: FontWeight.w400,
        color: onSurfaceVariant,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: onSurfaceVariant,
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Input Decoration (DESIGN.md §4 - Input Fields)
  // ──────────────────────────────────────────────

  static InputDecorationTheme _inputDecorationTheme({
    required Color fillColor,
    required Color hintColor,
    required Color focusedBorderColor,
  }) {
    return InputDecorationTheme(
      filled: true,
      fillColor: fillColor,
      hintStyle: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: hintColor,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: BorderSide(color: focusedBorderColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Button Themes (DESIGN.md §4 - Fitts's Law)
  // ──────────────────────────────────────────────

  static ElevatedButtonThemeData _elevatedButtonTheme({
    required Color foreground,
  }) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: foreground,
        backgroundColor: primary,
        minimumSize: const Size(double.infinity, minTouchTarget),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        elevation: 0,
      ),
    );
  }

  static OutlinedButtonThemeData _outlinedButtonTheme({
    required Color foreground,
    required Color borderColor,
  }) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground,
        minimumSize: const Size(double.infinity, minTouchTarget),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        side: BorderSide(color: borderColor),
        textStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Card Theme (DESIGN.md §4 - No-Line Rule)
  // ──────────────────────────────────────────────

  static CardThemeData _cardTheme({required Color color}) {
    return CardThemeData(
      color: color,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8),
    );
  }

  // ──────────────────────────────────────────────
  // Public Theme Builders
  // ──────────────────────────────────────────────

  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      colorScheme: const ColorScheme.dark(
        primary: primary,
        primaryContainer: primaryContainer,
        secondary: secondaryDark,
        tertiary: tertiary,
        surface: darkSurface,
        surfaceContainerHighest: darkSurfaceContainerHigh,
        onSurface: darkOnSurface,
        onSurfaceVariant: darkOnSurfaceVariant,
        error: Colors.redAccent,
      ),
      scaffoldBackgroundColor: darkSurface,
      textTheme: _buildTextTheme(base.textTheme, darkOnSurface, darkOnSurfaceVariant),
      inputDecorationTheme: _inputDecorationTheme(
        fillColor: darkSurfaceContainerHigh,
        hintColor: darkOnSurfaceVariant,
        focusedBorderColor: primary,
      ),
      elevatedButtonTheme: _elevatedButtonTheme(foreground: Colors.white),
      outlinedButtonTheme: _outlinedButtonTheme(
        foreground: darkOnSurface,
        borderColor: darkSurfaceContainerHigh,
      ),
      cardTheme: _cardTheme(color: darkSurfaceContainer),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: darkOnSurface,
        ),
        iconTheme: const IconThemeData(color: darkOnSurface),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkSurfaceContainer,
        selectedItemColor: primary,
        unselectedItemColor: darkOnSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: CircleBorder(),
      ),
      dividerTheme: const DividerThemeData(
        color: Colors.transparent, // No-Line Rule
        thickness: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkSurfaceContainer,
        contentTextStyle: GoogleFonts.inter(color: darkOnSurface, fontSize: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      colorScheme: const ColorScheme.light(
        primary: primary,
        primaryContainer: primaryContainer,
        secondary: secondaryLight,
        tertiary: tertiary,
        surface: lightSurface,
        surfaceContainerHighest: lightSurfaceContainerHigh,
        onSurface: lightOnSurface,
        onSurfaceVariant: lightOnSurfaceVariant,
        error: Colors.redAccent,
      ),
      scaffoldBackgroundColor: lightSurface,
      textTheme: _buildTextTheme(base.textTheme, lightOnSurface, lightOnSurfaceVariant),
      inputDecorationTheme: _inputDecorationTheme(
        fillColor: lightSurfaceContainerHigh,
        hintColor: lightOnSurfaceVariant,
        focusedBorderColor: primary,
      ),
      elevatedButtonTheme: _elevatedButtonTheme(foreground: Colors.white),
      outlinedButtonTheme: _outlinedButtonTheme(
        foreground: lightOnSurface,
        borderColor: lightSurfaceContainerHigh,
      ),
      cardTheme: _cardTheme(color: lightSurfaceContainer),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: lightOnSurface,
        ),
        iconTheme: const IconThemeData(color: lightOnSurface),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: lightSurfaceContainer,
        selectedItemColor: primary,
        unselectedItemColor: lightOnSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: CircleBorder(),
      ),
      dividerTheme: const DividerThemeData(
        color: Colors.transparent,
        thickness: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: lightSurfaceContainer,
        contentTextStyle: GoogleFonts.inter(color: lightOnSurface, fontSize: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
