import 'package:flutter/material.dart';

class AppColors {
  // Ultra-crisp boutique light palette
  static const Color bgLight = Color(0xFFF8FAFC); // Slate-50 background
  static const Color bgDark = Color(0xFFF8FAFC); // Alias for safety
  static const Color bgCard = Color(0xFFFFFFFF);
  static const Color bgSurface = Color(0xFFF1F5F9); // Slate-100
  static const Color bgInput = Color(0xFFF8FAFC);
  static const Color bgHover = Color(0xFFE2E8F0);

  // Borders
  static const Color borderLight = Color(0xFFE2E8F0); // Crisp 1px border
  static const Color borderFocus = Color(0xFFCBD5E1);

  // Typography
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF475569); // Slate 600
  static const Color textMuted = Color(0xFF94A3B8); // Slate 400

  // Luxury Boutique Accents
  static const Color accentGold = Color(0xFFB45309); // Rich Amber Gold
  static const Color accentGoldLight = Color(0xFFFFFBEB); // Warm Gold tint
  static const Color accentGoldBorder = Color(0xFFFDE68A);
  static const Color accentGoldHover = Color(0xFFD97706);
  
  static const Color accentDanger = Color(0xFFE11D48); // Rose-600
  static const Color accentDangerLight = Color(0xFFFFF1F2);
  
  static const Color accentSuccess = Color(0xFF059669); // Emerald-600
  static const Color accentSuccessLight = Color(0xFFECFDF5);
  
  static const Color accentBlue = Color(0xFF2563EB); // Royal Blue
  static const Color accentBlueLight = Color(0xFFEFF6FF);
  
  static const Color accentWarning = Color(0xFFD97706);
  static const Color accentPurple = Color(0xFF7C3AED);
  static const Color accentPurpleLight = Color(0xFFF5F3FF);

  // Gradients
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFD97706), Color(0xFFB45309)],
  );

  static const LinearGradient cardGlowGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFDF5), Color(0xFFFFFFFF)],
  );

  // Shadows
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x060F172A),
      blurRadius: 10,
      offset: Offset(0, 3),
    ),
    BoxShadow(
      color: Color(0x040F172A),
      blurRadius: 3,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: Color(0x0E0F172A),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.bgLight,
      primaryColor: AppColors.accentGold,
      fontFamily: 'Roboto',
      colorScheme: const ColorScheme.light(
        primary: AppColors.accentGold,
        secondary: AppColors.accentBlue,
        surface: AppColors.bgCard,
        error: AppColors.accentDanger,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
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
              fontWeight: FontWeight.w700,
            );
          }
          return const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          );
        }),
      ),
    );
  }

  static ThemeData get theme => lightTheme;
  static ThemeData get darkTheme => lightTheme;
}
