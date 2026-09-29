import 'package:flutter/material.dart';

class AppColors {
  // Deep luxury dark palette inspired by ScaleEzy Web
  static const Color bgDark = Color(0xFF000000);
  static const Color bgCard = Color(0xFF0D0D11);
  static const Color bgSurface = Color(0xFF14141A);
  static const Color bgInput = Color(0xFF1A1A22);
  static const Color bgHover = Color(0xFF22222D);

  // Borders
  static const Color borderLight = Color(0x1AFFFFFF); // rgba(255, 255, 255, 0.1)
  static const Color borderFocus = Color(0x33FFFFFF); // rgba(255, 255, 255, 0.2)

  // Typography
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA1A1AA);
  static const Color textMuted = Color(0xFF71717A);

  // Boutique Accent Colors
  static const Color accentGold = Color(0xFFE2C171);
  static const Color accentGoldHover = Color(0xFFFCD34D);
  static const Color accentDanger = Color(0xFFEF4444);
  static const Color accentSuccess = Color(0xFF10B981);
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color accentWarning = Color(0xFFF59E0B);
  static const Color accentPurple = Color(0xFFA855F7);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bgDark,
      primaryColor: AppColors.accentGold,
      fontFamily: 'Roboto', // Default clean font
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accentGold,
        secondary: AppColors.accentBlue,
        surface: AppColors.bgCard,
        error: AppColors.accentDanger,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgDark,
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
        indicatorColor: AppColors.accentGold.withValues(alpha: 0.15),
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
