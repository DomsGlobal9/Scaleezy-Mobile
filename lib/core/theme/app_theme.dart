import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// The colour a status or alert is drawn in. Pills use the tone for text and [tint] for fill.
enum Tone { neutral, info, warning, gold, success, danger, purple }

/// [color] at [alpha]: the pale fill behind tone-coloured text.
Color tint(Color color, [double alpha = 0.12]) =>
    color.withValues(alpha: alpha);

/// The website's design tokens (docs/design.md), one set per brightness.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Brightness brightness;
  final Color bg;
  final Color card;
  final Color input;
  final Color hover;
  final Color border;
  final Color borderFocus;
  final Color text;
  final Color textSecondary;
  final Color textMuted;

  /// Lime, for fills only; never text.
  final Color brand;

  /// Brand-coloured text and links.
  final Color brandInk;

  /// Primary actions (brand CTA, scan button) and [onBrandSolid] on top of them.
  final Color brandSolid;
  final Color onBrandSolid;

  /// Highlight only, never "primary".
  final Color gold;
  final Color danger;
  final Color success;
  final Color warning;
  final Color info;
  final Color purple;
  final Color neutral;
  final List<BoxShadow> panelShadow;

  const AppPalette({
    required this.brightness,
    required this.bg,
    required this.card,
    required this.input,
    required this.hover,
    required this.border,
    required this.borderFocus,
    required this.text,
    required this.textSecondary,
    required this.textMuted,
    required this.brand,
    required this.brandInk,
    required this.brandSolid,
    required this.onBrandSolid,
    required this.gold,
    required this.danger,
    required this.success,
    required this.warning,
    required this.info,
    required this.purple,
    required this.neutral,
    required this.panelShadow,
  });

  static const light = AppPalette(
    brightness: Brightness.light,
    bg: Color(0xFFFAFAFA),
    card: Color(0xFFFFFFFF),
    input: Color(0xFFF4F4F5),
    hover: Color(0xFFF4F4F5),
    border: Color(0x0F000000),
    borderFocus: Color(0x26000000),
    text: Color(0xFF18181B),
    textSecondary: Color(0xFF71717A),
    textMuted: Color(0xFF757580),
    brand: Color(0xFFA6D92B),
    brandInk: Color(0xFF164B1E),
    brandSolid: Color(0xFF164B1E),
    onBrandSolid: Color(0xFFFFFFFF),
    gold: Color(0xFFB48600),
    danger: Color(0xFFB91C1C),
    success: Color(0xFF047857),
    warning: Color(0xFFB45309),
    info: Color(0xFF1D4ED8),
    purple: Color(0xFF6D28D9),
    neutral: Color(0xFF4B5563),
    panelShadow: [
      BoxShadow(
        color: Color(0x0F000000),
        blurRadius: 24,
        spreadRadius: -4,
        offset: Offset(0, 4),
      ),
    ],
  );

  static const dark = AppPalette(
    brightness: Brightness.dark,
    bg: Color(0xFF000000),
    card: Color(0xFF0A0A0A),
    input: Color(0xFF111111),
    hover: Color(0xFF1A1A1A),
    border: Color(0x14FFFFFF),
    borderFocus: Color(0x33FFFFFF),
    text: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFA1A1AA),
    textMuted: Color(0xFF7B7B86),
    brand: Color(0xFFA6D92B),
    brandInk: Color(0xFFA6D92B),
    brandSolid: Color(0xFFA6D92B),
    onBrandSolid: Color(0xFF0B2410),
    gold: Color(0xFFE2C171),
    danger: Color(0xFFEF4444),
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    info: Color(0xFF3B82F6),
    purple: Color(0xFF8B5CF6),
    neutral: Color(0xFF9CA3AF),
    panelShadow: [
      BoxShadow(
        color: Color(0x80000000),
        blurRadius: 24,
        spreadRadius: -1,
        offset: Offset(0, 4),
      ),
    ],
  );

  Color tone(Tone tone) => switch (tone) {
    Tone.neutral => neutral,
    Tone.info => info,
    Tone.warning => warning,
    Tone.gold => gold,
    Tone.success => success,
    Tone.danger => danger,
    Tone.purple => purple,
  };

  // The palette is only ever one of two fixed sets, so nothing needs overriding.
  @override
  AppPalette copyWith() => this;

  // shortcut: snaps halfway instead of blending, so a theme switch jumps rather than fades for
  // widgets reading the palette; blend each colour if that animation is ever wanted.
  @override
  AppPalette lerp(AppPalette? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

extension AppPaletteContext on BuildContext {
  /// The current palette; falls back by brightness when a test theme has no extension.
  AppPalette get colors {
    final theme = Theme.of(this);
    return theme.extension<AppPalette>() ??
        (theme.brightness == Brightness.dark
            ? AppPalette.dark
            : AppPalette.light);
  }
}

class AppTheme {
  static final ThemeData light = _build(AppPalette.light);
  static final ThemeData dark = _build(AppPalette.dark);

  static ThemeData get lightTheme => light;
  static ThemeData get darkTheme => dark;
  static ThemeData get theme => light;

  static ThemeData _build(AppPalette p) {
    final isDark = p.brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: p.brightness,
      primary: p.brandSolid,
      onPrimary: p.onBrandSolid,
      secondary: p.gold,
      onSecondary: p.card,
      error: p.danger,
      onError: Colors.white,
      surface: p.card,
      onSurface: p.text,
      onSurfaceVariant: p.textSecondary,
      surfaceContainerLowest: p.card,
      surfaceContainerLow: p.card,
      surfaceContainer: p.card,
      surfaceContainerHigh: p.card,
      surfaceContainerHighest: p.input,
      outline: p.borderFocus,
      outlineVariant: p.border,
      inverseSurface: p.text,
      onInverseSurface: p.card,
      surfaceTint: Colors.transparent,
    );

    TextStyle s(double size, FontWeight weight, [double? spacing]) =>
        TextStyle(fontSize: size, fontWeight: weight, letterSpacing: spacing);
    final base = ThemeData(brightness: p.brightness, useMaterial3: true);
    var text = GoogleFonts.interTextTheme(
      base.textTheme.copyWith(
        headlineSmall: s(24, FontWeight.w700, -0.48), // page title
        titleLarge: s(18, FontWeight.w600), // big card / dialog title
        titleMedium: s(16, FontWeight.w600), // card title
        titleSmall: s(14, FontWeight.w600), // row title
        bodyLarge: s(15, FontWeight.w400),
        bodyMedium: s(14, FontWeight.w400),
        bodySmall: s(13, FontWeight.w400), // secondary lines
        labelLarge: s(14, FontWeight.w500), // buttons
        labelMedium: s(12, FontWeight.w500), // captions, pills
        labelSmall: s(
          11,
          FontWeight.w600,
          0.55,
        ), // caps labels (uppercase the string)
      ),
    ).apply(bodyColor: p.text, displayColor: p.text);
    text = text.copyWith(
      bodySmall: text.bodySmall!.copyWith(color: p.textSecondary),
      labelSmall: text.labelSmall!.copyWith(color: p.textSecondary),
    );

    final radius8 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    );
    OutlineInputBorder field(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: color),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: scheme,
      primaryColor: p.brandSolid,
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.card,
      dividerColor: p.border,
      textTheme: text,
      extensions: [p],
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        foregroundColor: p.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        iconTheme: IconThemeData(color: p.text),
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.text,
          foregroundColor: p.card,
          disabledBackgroundColor: tint(p.text, 0.5),
          disabledForegroundColor: p.card,
          minimumSize: const Size(64, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: radius8,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: p.card,
          foregroundColor: p.text,
          side: BorderSide(color: p.border),
          minimumSize: const Size(64, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: radius8,
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.brandInk,
          shape: radius8,
          textStyle: text.labelLarge!.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: p.text,
          minimumSize: const Size.square(44),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.brandSolid,
        foregroundColor: p.onBrandSolid,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.input,
        // The web puts the label above the field; it never floats in and out.
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: text.bodySmall!.copyWith(fontWeight: FontWeight.w500),
        floatingLabelStyle: text.bodySmall!.copyWith(
          fontWeight: FontWeight.w500,
        ),
        hintStyle: text.bodyMedium!.copyWith(color: p.textMuted),
        prefixIconColor: p.textSecondary,
        suffixIconColor: p.textSecondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: field(p.border),
        enabledBorder: field(p.border),
        disabledBorder: field(p.border),
        focusedBorder: field(p.borderFocus),
        errorBorder: field(p.danger),
        focusedErrorBorder: field(p.danger),
      ),
      cardTheme: CardThemeData(
        color: p.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: p.border),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.input,
        selectedColor: p.text,
        checkmarkColor: p.card,
        side: BorderSide(color: p.border),
        shape: radius8,
        labelStyle: text.bodySmall!.copyWith(
          fontWeight: FontWeight.w500,
          color: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected) ? p.card : p.text,
          ),
        ),
      ),
      // Like the filter chips: selected is ink on the card colour, never gold.
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: p.input,
          foregroundColor: p.textSecondary,
          selectedBackgroundColor: p.text,
          selectedForegroundColor: p.card,
          side: BorderSide(color: p.border),
          shape: radius8,
          textStyle: text.labelLarge,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: p.brandSolid, width: 2),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: p.text,
        unselectedLabelColor: p.textSecondary,
        labelStyle: text.titleSmall,
        unselectedLabelStyle: text.titleSmall!.copyWith(
          fontWeight: FontWeight.w500,
        ),
        dividerColor: p.border,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: p.input,
        indicatorShape: radius8,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium!.copyWith(
            color: states.contains(WidgetState.selected)
                ? p.text
                : p.textSecondary,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? p.text
                : p.textSecondary,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyLarge!.copyWith(
          color: p.textSecondary,
          height: 1.5,
        ),
      ),
      // showDragHandle stays per-call: several screens still draw their own handle.
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.card,
        modalBackgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        dragHandleColor: p.borderFocus,
        dragHandleSize: const Size(40, 4),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.card,
        contentTextStyle: text.bodyMedium,
        actionTextColor: p.brandInk,
        closeIconColor: p.textSecondary,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: p.border),
        ),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: p.textSecondary,
        textColor: p.text,
        titleTextStyle: text.titleSmall,
        subtitleTextStyle: text.bodySmall,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.brandSolid,
        linearTrackColor: p.input,
        circularTrackColor: Colors.transparent,
      ),
    );
  }
}
