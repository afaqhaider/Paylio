import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppThemes {
  // Brand Colors - Premium Dark Fintech Identity
  static const Color darkBg = Color(0xFF0B1120);
  static const Color darkSurface = Color(0xFF111827);
  static const Color darkBorder = Color(0xFF1F2937);
  
  // New LedGix Blue Accent System
  static const Color accentBlue = Color(0xFF218BFF);
  static const Color accentBlueSecondary = Color(0xFF1D9BF0);
  static const Color accentSoftBlue = Color(0xFF3B82F6);
  static const Color softCyan = Color(0xFF2DD4BF); // For subtle secondary highlights
  
  static const Color textPrimary = Color(0xFFF9FAFB);
  static const Color textSecondary = Color(0xFF94A3B8); // Muted gray-blue
  
  static const Color incomeGreen = Color(0xFF10B981);
  static const Color expenseRed = Color(0xFFEF4444);

  static ThemeData getLightTheme() {
    return _buildTheme(Brightness.light);
  }

  static ThemeData getDarkTheme() {
    return _buildTheme(Brightness.dark);
  }

  // Maintaining old names for compatibility
  static ThemeData getPremiumFinance() => getDarkTheme();
  static ThemeData getModernLedGix() => getDarkTheme();
  static ThemeData getDarkMoneyApp() => getDarkTheme();

  static ThemeData _buildTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: accentBlue,
      brightness: brightness,
      primary: accentBlue,
      onPrimary: Colors.white,
      secondary: accentBlueSecondary,
      tertiary: softCyan,
      surface: isDark ? darkSurface : Colors.white,
      background: isDark ? darkBg : const Color(0xFFF8FAFC),
      onSurface: isDark ? textPrimary : const Color(0xFF0F172A),
      outline: isDark ? darkBorder : const Color(0xFFE2E8F0),
    );

    final TextTheme textTheme = GoogleFonts.manropeTextTheme(
      TextTheme(
        displayLarge: TextStyle(color: isDark ? textPrimary : Colors.black, fontWeight: FontWeight.w900),
        displayMedium: TextStyle(color: isDark ? textPrimary : Colors.black, fontWeight: FontWeight.w900),
        displaySmall: TextStyle(color: isDark ? textPrimary : Colors.black, fontWeight: FontWeight.w900),
        headlineLarge: TextStyle(color: isDark ? textPrimary : Colors.black, fontWeight: FontWeight.w800),
        headlineMedium: TextStyle(color: isDark ? textPrimary : Colors.black, fontWeight: FontWeight.w800),
        headlineSmall: TextStyle(color: isDark ? textPrimary : Colors.black, fontWeight: FontWeight.w800),
        titleLarge: TextStyle(color: isDark ? textPrimary : Colors.black, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: isDark ? textPrimary : Colors.black, fontWeight: FontWeight.w700),
        titleSmall: TextStyle(color: isDark ? textPrimary : Colors.black, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(color: isDark ? textPrimary : Colors.black87, fontSize: 16),
        bodyMedium: TextStyle(color: isDark ? textSecondary : Colors.black54, fontSize: 14),
        bodySmall: TextStyle(color: isDark ? textSecondary : Colors.black54, fontSize: 12),
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark ? darkBg : colorScheme.background,
      textTheme: textTheme,
      fontFamily: GoogleFonts.manrope().fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? darkBg : Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        iconTheme: IconThemeData(color: isDark ? textPrimary : Colors.black),
      ),
      cardTheme: CardThemeData(
        color: isDark ? darkSurface : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: isDark ? darkBorder : const Color(0xFFE2E8F0), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 58),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? textPrimary : Colors.black,
          side: BorderSide(color: colorScheme.outline, width: 1.5),
          minimumSize: const Size(double.infinity, 58),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? darkSurface : Colors.white,
        indicatorColor: accentBlue.withOpacity(0.1),
        height: 70,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: accentBlue, size: 26);
          }
          return IconThemeData(color: textSecondary.withOpacity(0.6), size: 26);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.bodySmall?.copyWith(color: accentBlue, fontWeight: FontWeight.w800, fontSize: 11);
          }
          return textTheme.bodySmall?.copyWith(color: textSecondary.withOpacity(0.6), fontSize: 11);
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accentBlue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? darkSurface : Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: accentBlue, width: 2),
        ),
        labelStyle: TextStyle(color: textSecondary, fontWeight: FontWeight.w600),
        hintStyle: TextStyle(color: textSecondary.withOpacity(0.4)),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outline,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodySmall,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: accentBlue,
        circularTrackColor: Colors.transparent,
      ),
    );
  }
}
