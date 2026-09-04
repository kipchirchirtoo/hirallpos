import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Brand & Core — SacComply / Ona Grey & Emerald Design System
  static const Color primary = Color(0xFF059669); // SacComply Emerald Green (#059669)
  static const Color primaryHover = Color(0xFF047857);
  static const Color primaryLight = Color(0xFFECFDF5);

  static const Color accent = Color(0xFFD97757); // SacComply Signature Clay (#D97757)
  static const Color secondary = Color(0xFF222220); // Warm Graphite Grey

  // Status & Feedback
  static const Color success = Color(0xFF10B981); // Emerald
  static const Color successLight = Color(0xFFECFDF5);
  static const Color warning = Color(0xFFD97706); // Amber
  static const Color warningLight = Color(0xFFFFFBEB);
  static const Color danger = Color(0xFFDC2626); // Crimson Red
  static const Color dangerLight = Color(0xFFFEF2F2);
  static const Color info = Color(0xFF0284C7); // Sky Blue

  // Dark Theme Palette (Onyx Charcoal & Graphite)
  static const Color darkBg = Color(0xFF141413); // Onyx Charcoal
  static const Color darkSurface = Color(0xFF1E1E1C); // Dark Graphite Surface
  static const Color darkCard = Color(0xFF242422); // Warm Grey Card
  static const Color darkCardHover = Color(0xFF2C2C29);
  static const Color darkBorder = Color(0xFF2D2D2B); // Warm Slate Border
  static const Color darkTextPrimary = Color(0xFFEDECE6); // Warm Off-White / Ivory
  static const Color darkTextSecondary = Color(0xFF999891); // Neutral Mid Grey
  static const Color darkTextMuted = Color(0xFF666560); // Muted Grey

  // Light Theme Palette (Primary Grey Theme: Porcelain & Sand Grey)
  static const Color lightBg = Color(0xFFFAF9F5); // Porcelain Warm Ivory / Sand
  static const Color lightSurface = Color(0xFFFFFFFF); // Crisp White Surface
  static const Color lightCard = Color(0xFFFFFFFF); // White Card on Sand
  static const Color lightCardHover = Color(0xFFF4F3EE);
  static const Color lightBorder = Color(0xFFE5E3D8); // Sand Stone Grey Border
  static const Color lightTextPrimary = Color(0xFF141413); // Dark Onyx Text
  static const Color lightTextSecondary = Color(0xFF666560); // Stone Grey
  static const Color lightTextMuted = Color(0xFF999891); // Muted Grey

  // Dynamic Context-Aware Getters
  static bool isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

  static Color bg(BuildContext context) => isDark(context) ? darkBg : lightBg;
  static Color surface(BuildContext context) => isDark(context) ? darkSurface : lightSurface;
  static Color card(BuildContext context) => isDark(context) ? darkCard : lightCard;
  static Color cardHover(BuildContext context) => isDark(context) ? darkCardHover : lightCardHover;
  static Color border(BuildContext context) => isDark(context) ? darkBorder : lightBorder;
  static Color textPrimary(BuildContext context) => isDark(context) ? darkTextPrimary : lightTextPrimary;
  static Color textSecondary(BuildContext context) => isDark(context) ? darkTextSecondary : lightTextSecondary;
  static Color textMuted(BuildContext context) => isDark(context) ? darkTextMuted : lightTextMuted;

  // M-Pesa Brand
  static const Color mpesaGreen = Color(0xFF00A859);
}

class AppTheme {
  // 1. PRIMARY LIGHT GREY THEME (Default)
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.lightBg,
    primaryColor: AppColors.primary,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.lightSurface,
      error: AppColors.danger,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.lightTextPrimary,
    ),
    textTheme: GoogleFonts.plusJakartaSansTextTheme(
      const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.lightTextPrimary),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.lightTextPrimary),
        headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.lightTextPrimary),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.lightTextPrimary),
        titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.lightTextPrimary),
        bodyLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.lightTextPrimary),
        bodyMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.lightTextSecondary),
        labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.lightTextPrimary),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.lightCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.lightBorder, width: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.lightSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.lightBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.lightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      hintStyle: const TextStyle(color: AppColors.lightTextMuted, fontSize: 14),
      labelStyle: const TextStyle(color: AppColors.lightTextSecondary, fontSize: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.lightTextPrimary,
        side: const BorderSide(color: AppColors.lightBorder),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.lightBorder,
      thickness: 1,
      space: 1,
    ),
  );

  // 2. DARK GRAPHITE THEME
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBg,
    primaryColor: AppColors.primary,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.darkSurface,
      error: AppColors.danger,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.darkTextPrimary,
    ),
    textTheme: GoogleFonts.plusJakartaSansTextTheme(
      const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.darkTextPrimary),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.darkTextPrimary),
        headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.darkTextPrimary),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.darkTextPrimary),
        titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.darkTextPrimary),
        bodyLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.darkTextPrimary),
        bodyMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.darkTextSecondary),
        labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.darkTextPrimary),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.darkCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.darkBorder, width: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      hintStyle: const TextStyle(color: AppColors.darkTextMuted, fontSize: 14),
      labelStyle: const TextStyle(color: AppColors.darkTextSecondary, fontSize: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.darkTextPrimary,
        side: const BorderSide(color: AppColors.darkBorder),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.darkBorder,
      thickness: 1,
      space: 1,
    ),
  );
}
