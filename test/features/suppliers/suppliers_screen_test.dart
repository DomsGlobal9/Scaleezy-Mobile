import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/features/suppliers/presentation/suppliers_screen.dart';
import 'package:scaleezy/features/suppliers/presentation/view_models/suppliers_view_model.dart';

import 'suppliers_fakes.dart';

void main() {
  for (final (name, theme) in [
    ('light', AppTheme.light),
    ('dark', AppTheme.dark),
  ]) {
    testWidgets('suppliers screen shows what it loads ($name theme)', (
      tester,
    ) async {
      final vm = SuppliersViewModel(
        FakeSupplierRepository(
          () async => [
            supplier('1', name: 'Weavers Co', phone: '+919848022338'),
            supplier('2', name: 'Loom House'),
            supplier('3', name: 'Old Mill', active: false),
          ],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: SuppliersScreen(viewModel: vm),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(find.text('3 shown'), findsOneWidget);
      expect(find.text('Old Mill'), findsOneWidget);
      expect(find.text('Inactive'), findsOneWidget);
      expect(find.text('+91 98480 22338'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'loom');
      await tester.pumpAndSettle();
      expect(find.text('1 shown'), findsOneWidget);
      expect(find.text('Loom House'), findsOneWidget);
      expect(find.text('Weavers Co'), findsNothing);
    });
  }
}
