import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/features/scanner/presentation/scanner_screen.dart';
import 'package:scaleezy/features/scanner/presentation/view_models/scanner_view_model.dart';

import 'scanner_fakes.dart';

void main() {
  testWidgets('a typed code shows the piece its view model finds', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeProductRepository(
      (_) async => [piece('a', title: 'Banarasi Saree', quantity: 7)],
    );
    // Camera off: the tab is not showing.
    await tester.pumpWidget(
      SessionScope(
        session: AuthSession(offlineClient()),
        child: MaterialApp(
          home: ScannerScreen(active: false, viewModel: ScannerViewModel(repo)),
        ),
      ),
    );
    expect(find.text('Scan a garment tag to see its stock'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '890a');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(repo.calls.single['q'], '890a');
    expect(find.text('Banarasi Saree'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
  });
}
