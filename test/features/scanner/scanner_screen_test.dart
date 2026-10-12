import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/features/scanner/presentation/scanner_screen.dart';
import 'package:scaleezy/features/scanner/presentation/view_models/scanner_view_model.dart';

import 'scanner_fakes.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    FakeProductRepository repo,
    ThemeData theme,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Camera off: the tab is not showing.
    await tester.pumpWidget(
      SessionScope(
        session: AuthSession(offlineClient()),
        child: MaterialApp(
          theme: theme,
          home: ScannerScreen(active: false, viewModel: ScannerViewModel(repo)),
        ),
      ),
    );
  }

  Future<void> type(WidgetTester tester, String code) async {
    await tester.enterText(find.byType(TextField), code);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    final mode = theme.brightness.name;

    testWidgets('an exact code shows the verified piece ($mode)', (
      tester,
    ) async {
      final saree = piece('a', title: 'Banarasi Saree', quantity: 7);
      final repo = FakeProductRepository(
        (_) async => [saree],
        found: (_) async => exactHits([saree]),
      );
      await pump(tester, repo, theme);
      expect(find.text('Scan a garment tag to see its stock'), findsOneWidget);
      expect(find.text('Point at the barcode'), findsOneWidget);

      await type(tester, '890A');

      expect(repo.searched.single, '890A');
      expect(find.text('Banarasi Saree'), findsOneWidget);
      expect(find.text('SKU Match Verified'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('7 in stock'), findsOneWidget);
      expect(find.text('pieces'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a name search pick is not called verified ($mode)', (
      tester,
    ) async {
      final repo = FakeProductRepository(
        (_) async => [piece('a', title: 'Banarasi Saree', quantity: -2)],
      );
      await pump(tester, repo, theme);
      await type(tester, 'banarasi');

      expect(repo.calls.single['q'], 'banarasi');
      expect(find.text('Banarasi Saree'), findsOneWidget);
      expect(find.text('SKU Match Verified'), findsNothing);
      expect(find.text('-2 · oversold'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('nothing found says so in the website words ($mode)', (
      tester,
    ) async {
      final repo = FakeProductRepository((_) async => []);
      await pump(tester, repo, theme);
      await type(tester, 'XYZ');

      expect(
        find.text('Nothing found for "XYZ". Check the barcode or SKU.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
