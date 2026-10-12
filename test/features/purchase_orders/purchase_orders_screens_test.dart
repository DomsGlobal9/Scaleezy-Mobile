import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/features/purchase_orders/presentation/purchase_orders_screen.dart';
import 'package:scaleezy/features/purchase_orders/presentation/view_models/purchase_orders_view_model.dart';

import 'purchase_orders_fakes.dart';

void main() {
  testWidgets('purchase orders screen shows what its view model loads', (
    tester,
  ) async {
    final vm = PurchaseOrdersViewModel(
      FakePurchaseOrderRepository(
        list: () async => [
          summary('1', status: 'SENT', supplier: 'Weavers Co'),
          summary('2', status: 'DRAFT', supplier: 'Loom House'),
        ],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: PurchaseOrdersScreen(viewModel: vm)),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 waiting to be received'), findsOneWidget);
    expect(find.text('Weavers Co'), findsOneWidget);
    expect(find.text('Loom House'), findsNothing);

    await tester.tap(find.text('Draft  1'));
    await tester.pumpAndSettle();
    expect(vm.filter, 'DRAFT');
    expect(find.text('Weavers Co'), findsNothing);
    expect(find.text('Loom House'), findsOneWidget);
  });
}
