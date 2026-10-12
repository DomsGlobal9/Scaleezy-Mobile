import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/shop/shop_context.dart';
import 'package:scaleezy/core/shop/shop_models.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/features/dashboard/presentation/home_screen.dart';
import 'package:scaleezy/features/dashboard/presentation/view_models/home_view_model.dart';

import '../orders/orders_fakes.dart';
import '../products/products_fakes.dart' show offlineClient;
import '../purchase_orders/purchase_orders_fakes.dart' as po;
import 'dashboard_fakes.dart';

/// Signed in with exactly [perms].
class _Role extends AuthSession {
  _Role(this.perms) : super(offlineClient());
  final Set<String> perms;

  @override
  bool can(String permission) => perms.contains(permission);
}

/// One store, already chosen.
class _Shop extends ShopContext {
  _Shop() : super(offlineClient());
  static const _main = StockLocation(
    id: 's1',
    code: 'MAIN-STORE',
    name: 'Main Store',
    type: 'STORE',
    active: true,
  );

  @override
  List<StockLocation> get locations => const [_main];

  @override
  StockLocation? get selectedLocation => _main;
}

void main() {
  Future<void> pump(
    WidgetTester tester,
    HomeViewModel vm, {
    AuthSession? session,
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      SessionScope(
        session: session ?? AuthSession(offlineClient()),
        child: ShopScope(
          shop: _Shop(),
          child: MaterialApp(
            theme: theme ?? AppTheme.light,
            home: HomeScreen(viewModel: vm),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

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

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets(
      'money tiles and the low-stock list (${theme.brightness.name})',
      (tester) async {
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
          session: _Role({
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
      },
    );

    testWidgets(
      'empty lists use the website words (${theme.brightness.name})',
      (tester) async {
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
          session: _Role({'inventory:view'}),
        );

        expect(find.text('No low-stock alerts right now.'), findsOneWidget);
        expect(find.text('No recent activity.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
