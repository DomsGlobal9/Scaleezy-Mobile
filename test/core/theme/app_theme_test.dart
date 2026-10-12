import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/theme/app_theme.dart';

void main() {
  // Building a theme asks google_fonts to load Inter, which needs the binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('light palette is the website light tokens', () {
    const p = AppPalette.light;
    expect(p.brightness, Brightness.light);
    expect(p.bg, const Color(0xFFFAFAFA));
    expect(p.card, const Color(0xFFFFFFFF));
    expect(p.input, const Color(0xFFF4F4F5));
    expect(p.hover, const Color(0xFFF4F4F5));
    expect(p.border, const Color(0x0F000000));
    expect(p.borderFocus, const Color(0x26000000));
    expect(p.text, const Color(0xFF18181B));
    expect(p.textSecondary, const Color(0xFF71717A));
    expect(p.textMuted, const Color(0xFF757580));
    expect(p.brand, const Color(0xFFA6D92B));
    expect(p.brandInk, const Color(0xFF164B1E));
    expect(p.brandSolid, const Color(0xFF164B1E));
    expect(p.onBrandSolid, const Color(0xFFFFFFFF));
    expect(p.gold, const Color(0xFFB48600));
    expect(p.danger, const Color(0xFFB91C1C));
    expect(p.success, const Color(0xFF047857));
    expect(p.warning, const Color(0xFFB45309));
    expect(p.info, const Color(0xFF1D4ED8));
    expect(p.purple, const Color(0xFF6D28D9));
    expect(p.neutral, const Color(0xFF4B5563));
    expect(p.panelShadow.single.color, const Color(0x0F000000));
    expect(p.panelShadow.single.spreadRadius, -4);
  });

  test('dark palette is the website dark tokens', () {
    const p = AppPalette.dark;
    expect(p.brightness, Brightness.dark);
    expect(p.bg, const Color(0xFF000000));
    expect(p.card, const Color(0xFF0A0A0A));
    expect(p.input, const Color(0xFF111111));
    expect(p.hover, const Color(0xFF1A1A1A));
    expect(p.border, const Color(0x14FFFFFF));
    expect(p.borderFocus, const Color(0x33FFFFFF));
    expect(p.text, const Color(0xFFFFFFFF));
    expect(p.textSecondary, const Color(0xFFA1A1AA));
    expect(p.textMuted, const Color(0xFF7B7B86));
    expect(p.brand, const Color(0xFFA6D92B));
    expect(p.brandInk, const Color(0xFFA6D92B));
    expect(p.brandSolid, const Color(0xFFA6D92B));
    expect(p.onBrandSolid, const Color(0xFF0B2410));
    expect(p.gold, const Color(0xFFE2C171));
    expect(p.danger, const Color(0xFFEF4444));
    expect(p.success, const Color(0xFF10B981));
    expect(p.warning, const Color(0xFFF59E0B));
    expect(p.info, const Color(0xFF3B82F6));
    expect(p.purple, const Color(0xFF8B5CF6));
    expect(p.neutral, const Color(0xFF9CA3AF));
    expect(p.panelShadow.single.color, const Color(0x80000000));
    expect(p.panelShadow.single.spreadRadius, -1);
  });

  test('every tone maps to its palette colour, and tint is 12%', () {
    const p = AppPalette.light;
    expect(p.tone(Tone.neutral), p.neutral);
    expect(p.tone(Tone.info), p.info);
    expect(p.tone(Tone.warning), p.warning);
    expect(p.tone(Tone.gold), p.gold);
    expect(p.tone(Tone.success), p.success);
    expect(p.tone(Tone.danger), p.danger);
    expect(p.tone(Tone.purple), p.purple);
    expect(tint(p.success).a, closeTo(0.12, 0.001));
    expect(tint(p.success, 0.16).a, closeTo(0.16, 0.001));
  });

  test('both themes build from their palette', () {
    for (final (theme, palette) in [
      (AppTheme.light, AppPalette.light),
      (AppTheme.dark, AppPalette.dark),
    ]) {
      expect(theme.brightness, palette.brightness);
      expect(theme.extension<AppPalette>(), palette);
      expect(theme.scaffoldBackgroundColor, palette.bg);
      expect(theme.colorScheme.primary, palette.brandSolid);
      expect(theme.colorScheme.secondary, palette.gold);
      expect(theme.colorScheme.error, palette.danger);
      expect(theme.colorScheme.surface, palette.card);
      expect(theme.colorScheme.outline, palette.borderFocus);
      expect(theme.colorScheme.outlineVariant, palette.border);
      expect(theme.textTheme.headlineSmall!.fontSize, 24);
      expect(theme.textTheme.headlineSmall!.fontWeight, FontWeight.w700);
      expect(theme.textTheme.headlineSmall!.fontFamily, contains('Inter'));
      expect(theme.navigationBarTheme.indicatorColor, palette.input);
      expect(theme.inputDecorationTheme.fillColor, palette.input);
      expect(theme.snackBarTheme.backgroundColor, palette.card);
    }
    expect(AppTheme.lightTheme, same(AppTheme.light));
    expect(AppTheme.darkTheme, same(AppTheme.dark));
  });

  testWidgets('context.colors follows the theme, light when none is set', (
    tester,
  ) async {
    late AppPalette seen;
    // A fresh app each time, so the theme does not animate from the previous one.
    Widget probe(ThemeData? theme) => MaterialApp(
      key: UniqueKey(),
      theme: theme,
      home: Builder(
        builder: (context) {
          seen = context.colors;
          return const SizedBox();
        },
      ),
    );
    await tester.pumpWidget(probe(AppTheme.dark));
    expect(seen, AppPalette.dark);
    await tester.pumpWidget(probe(null));
    expect(seen, AppPalette.light);
  });
}
