import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/features/dashboard/presentation/home_screen.dart';
import 'package:scaleezy/features/dashboard/presentation/view_models/home_view_model.dart';

import '../../support/pump.dart';
import '../../support/roles.dart';
import '../orders/orders_fakes.dart';
import '../purchase_orders/purchase_orders_fakes.dart' as po;
import 'dashboard_fakes.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    HomeViewModel vm, {
    AuthSession? session,
    ThemeMode theme = ThemeMode.light,
  }) => pumpScreen(
    tester,
    HomeScreen(viewModel: vm),
    session: session ?? TestSession(null),
    shop: TestShop(
      stores: [store('s1', code: 'MAIN-STORE', name: 'Main Store')],
    ),
    theme: theme,
    width: 400,
    height: 2400,
  );

  testWidgets(
    'home shows the basic summary, asking only for what the role may see',
    (tester) async {
      final inventory = FakeHomeInventoryRepository();
      final orders = FakeOrderRepository();
      final dashboard = FakeDashboardRepository(
        () async => summary(recent: [movementJson('r1', 4, DateTime.now())]),
      );
      final vm = HomeViewModel(
        dashboard: dashboard,
        inventory: inventory,
        orders: orders,
        purchaseOrders: po.FakePurchaseOrderRepository(),
      );
      await pump(tester, vm);

      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('PIECES IN STOCK · MAIN STORE'), findsOneWidget);
      expect(find.text('Recent Transactions'), findsOneWidget);
      // Signed out: no inventory:view, sales_order:view or report:financial.
      expect(find.text('Low Stock Items'), findsNothing);
      expect(find.text("Today's sales"), findsNothing);
      expect(dashboard.calls, ['summary']);
      expect(inventory.calls, isEmpty);
      expect(orders.searches, isEmpty);
    },
  );

  for (final theme in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('money tiles and the low-stock list (${theme.name})', (
      tester,
    ) async {
      final vm = HomeViewModel(
        dashboard: FakeDashboardRepository(
          () async => summary(),
          moneyAnswer: () async =>
              money(companyWideValue: 400000, outOfStockCount: 2),
          alerts: () async => [
            alert('l1', 'LOW_STOCK', quantity: 2),
            alert('o1', 'OUT_OF_STOCK', quantity: 0),
          ],
        ),
        inventory: FakeHomeInventoryRepository(
          movements: () async => [movement('m1', 5, DateTime.now())],
        ),
        orders: FakeOrderRepository(
          answer: () async => [order('a', total: 500, pieces: 2)],
        ),
        purchaseOrders: po.FakePurchaseOrderRepository(),
      );
      await pump(
        tester,
        vm,
        theme: theme,
        session: TestSession.as({
          'report:financial',
          'inventory:view',
          'inventory:receive',
          'sales_order:view',
          'purchase_order:view',
        }),
      );

      expect(find.text('INVENTORY VALUE · MAIN STORE'), findsOneWidget);
      expect(find.text('₹4,00,000 across all locations'), findsOneWidget);
      expect(find.text('OPEN PO VALUE'), findsOneWidget);
      expect(find.text('2 more are out of stock.'), findsOneWidget);
      expect(find.text("Today's sales"), findsOneWidget);
      expect(find.text('Out of stock'), findsOneWidget);
      expect(find.text('Low stock'), findsOneWidget);
      expect(find.text('0 / 5'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty lists use the website words (${theme.name})', (
      tester,
    ) async {
      final vm = HomeViewModel(
        dashboard: FakeDashboardRepository(
          () async => summary(),
          alerts: () async => [],
        ),
        inventory: FakeHomeInventoryRepository(movements: () async => []),
        orders: FakeOrderRepository(),
        purchaseOrders: po.FakePurchaseOrderRepository(),
      );
      await pump(
        tester,
        vm,
        theme: theme,
        session: TestSession.as({'inventory:view'}),
      );

      expect(find.text('No low-stock alerts right now.'), findsOneWidget);
      expect(find.text('No recent activity.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a low-stock row opens its product', (tester) async {
    final vm = HomeViewModel(
      dashboard: FakeDashboardRepository(
        () async => summary(),
        alerts: () async => [alert('l1', 'LOW_STOCK', quantity: 2)],
      ),
      inventory: FakeHomeInventoryRepository(movements: () async => []),
      orders: FakeOrderRepository(),
      purchaseOrders: po.FakePurchaseOrderRepository(),
    );
    await pump(tester, vm, session: TestSession.as({'inventory:view'}));

    await tester.tap(find.text('Saree l1'));
    await tester.pumpAndSettle();
    expect(find.text('Opened /products/p-l1'), findsOneWidget);
  });
}
