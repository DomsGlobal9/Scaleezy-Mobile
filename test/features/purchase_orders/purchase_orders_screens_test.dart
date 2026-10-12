import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/features/purchase_orders/presentation/purchase_orders_screen.dart';
import 'package:scaleezy/features/purchase_orders/presentation/view_models/purchase_order_view_model.dart';
import 'package:scaleezy/features/purchase_orders/presentation/view_models/purchase_orders_view_model.dart';
import 'package:scaleezy/features/purchase_orders/presentation/view_models/receive_delivery_view_model.dart';

import 'purchase_orders_fakes.dart';

void main() {
  PurchaseOrdersViewModel listVm() => PurchaseOrdersViewModel(
    FakePurchaseOrderRepository(
      list: () async => [
        summary('1', status: 'SENT', supplier: 'Weavers Co'),
        summary('2', status: 'DRAFT', supplier: 'Loom House'),
      ],
    ),
  );

  testWidgets('starts on every status, filters and searches', (tester) async {
    final vm = listVm();
    await tester.pumpWidget(
      MaterialApp(home: PurchaseOrdersScreen(viewModel: vm)),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 waiting to be received'), findsOneWidget);
    expect(find.text('Weavers Co'), findsOneWidget);
    expect(find.text('Loom House'), findsOneWidget);
    expect(find.text('Sent'), findsOneWidget);
    expect(find.text('Draft'), findsOneWidget);

    await tester.ensureVisible(find.text('Draft  1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Draft  1'));
    await tester.pumpAndSettle();
    expect(vm.filter, 'draft');
    expect(find.text('Weavers Co'), findsNothing);
    expect(find.text('Loom House'), findsOneWidget);

    await tester.ensureVisible(find.text('Cancelled  0'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelled  0'));
    await tester.pumpAndSettle();
    expect(find.text('No purchase orders with this status.'), findsOneWidget);
    await tester.tap(find.text('Show all'));
    await tester.pumpAndSettle();
    expect(vm.filter, '');

    await tester.enterText(find.byType(TextField), 'PO-1');
    await tester.pumpAndSettle();
    expect(find.text('Weavers Co'), findsOneWidget);
    expect(find.text('Loom House'), findsNothing);
  });

  testWidgets('the dashboard link ?filter=open still works', (tester) async {
    final vm = listVm();
    await tester.pumpWidget(
      MaterialApp(
        home: PurchaseOrdersScreen(viewModel: vm, filter: 'open'),
      ),
    );
    await tester.pumpAndSettle();
    expect(vm.filter, 'open');
    expect(find.text('Loom House'), findsNothing);
  });

  for (final (name, theme) in [
    ('light', AppTheme.light),
    ('dark', AppTheme.dark),
  ]) {
    testWidgets('purchase order screens render in the $name theme', (
      tester,
    ) async {
      final repo = FakePurchaseOrderRepository(
        list: () async => [
          summary('1', status: 'PARTIALLY_RECEIVED'),
          summary('2', status: 'CANCELLED'),
        ],
        one: () async => detail(),
      );
      Widget app(Widget home) => SessionScope(
        session: AuthSession(offlineClient()),
        child: MaterialApp(theme: theme, home: home),
      );

      await tester.pumpWidget(
        app(PurchaseOrdersScreen(viewModel: PurchaseOrdersViewModel(repo))),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Partly received'), findsWidgets);

      await tester.pumpWidget(
        app(
          PurchaseOrderScreen(
            poId: 'po1',
            viewModel: PurchaseOrderViewModel('po1', repo),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(' / 15 pieces received'), findsOneWidget);

      await tester.pumpWidget(
        app(
          ReceiveDeliveryScreen(
            po: detail(),
            viewModel: ReceiveDeliveryViewModel(detail(), repo),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Count the pieces'), findsOneWidget);
    });
  }
}
