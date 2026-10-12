import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/features/suppliers/presentation/suppliers_screen.dart';
import 'package:scaleezy/features/suppliers/presentation/view_models/suppliers_view_model.dart';

import 'suppliers_fakes.dart';

void main() {
  testWidgets('suppliers screen shows what its view model loads', (
    tester,
  ) async {
    final vm = SuppliersViewModel(
      FakeSupplierRepository(
        () async => [
          supplier('1', name: 'Weavers Co'),
          supplier('2', name: 'Loom House'),
          supplier('3', name: 'Old Mill', active: false),
        ],
      ),
    );
    await tester.pumpWidget(MaterialApp(home: SuppliersScreen(viewModel: vm)));
    await tester.pumpAndSettle();

    expect(find.text('2 shown'), findsOneWidget);
    expect(find.text('Old Mill'), findsNothing);

    await tester.tap(find.text('Show 1 inactive'));
    await tester.pumpAndSettle();
    expect(find.text('Old Mill'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'loom');
    await tester.pumpAndSettle();
    expect(find.text('1 shown'), findsOneWidget);
    expect(find.text('Loom House'), findsOneWidget);
    expect(find.text('Weavers Co'), findsNothing);
  });
}
