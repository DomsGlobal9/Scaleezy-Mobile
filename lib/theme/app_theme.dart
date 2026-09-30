import 'package:flutter/material.dart';

class AppColors {
  // Clean, premium light mode palette for ScaleEzy
  static const Color bgDark = Color(0xFFF8FAFC); // Main light background (slate 50)
  static const Color bgCard = Color(0xFFFFFFFF); // Pure white cards & navigation
  static const Color bgSurface = Color(0xFFF1F5F9); // Light surface / chips / badges (slate 100)
  static const Color bgInput = Color(0xFFF8FAFC); // Form inputs
  static const Color bgHover = Color(0xFFE2E8F0); // Hover/press states

  // Borders
  static const Color borderLight = Color(0xFFE2E8F0); // Subtle clean border
  static const Color borderFocus = Color(0xFFCBD5E1);

  // Typography
  static const Color textPrimary = Color(0xFF0F172A); // Deep slate 900 for high readability
  static const Color textSecondary = Color(0xFF475569); // Slate 600
  static const Color textMuted = Color(0xFF94A3B8); // Slate 400

  // Boutique Accent Colors
  static const Color accentGold = Color(0xFFB45309); // Rich amber/gold, high contrast on light bg
  static const Color accentGoldHover = Color(0xFF92400E);
  static const Color accentDanger = Color(0xFFDC2626);
  static const Color accentSuccess = Color(0xFF16A34A);
  static const Color accentBlue = Color(0xFF2563EB);
  static const Color accentWarning = Color(0xFFD97706);
  static const Color accentPurple = Color(0xFF7C3AED);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.bgDark,
      primaryColor: AppColors.accentGold,
      fontFamily: 'Roboto',
      colorScheme: const ColorScheme.light(
        primary: AppColors.accentGold,
        secondary: AppColors.accentBlue,
        surface: AppColors.bgCard,
        error: AppColors.accentDanger,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgCard,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.bgCard,
        indicatorColor: AppColors.accentGold.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: AppColors.accentGold,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            );
          }
          return const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.accentGold);
          }
          return const IconThemeData(color: AppColors.textSecondary);
        }),
      ),
    );
  }
}
