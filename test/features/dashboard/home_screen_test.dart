import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/shop/shop_context.dart';
import 'package:scaleezy/features/dashboard/presentation/home_screen.dart';
import 'package:scaleezy/features/dashboard/presentation/view_models/home_view_model.dart';

import '../orders/orders_fakes.dart';
import '../products/products_fakes.dart' show offlineClient;
import 'dashboard_fakes.dart';

void main() {
  testWidgets('home shows the summary, asking only for what the role may see', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final inventory = FakeHomeInventoryRepository();
    final orders = FakeOrderRepository();
    final vm = HomeViewModel(
      dashboard: FakeDashboardRepository(
        () async => summary(recent: [movementJson('r1', 4, DateTime.now())]),
      ),
      inventory: inventory,
      orders: orders,
    );
    await tester.pumpWidget(
      SessionScope(
        session: AuthSession(offlineClient()),
        child: ShopScope(
          shop: ShopContext(offlineClient()),
          child: MaterialApp(home: HomeScreen(viewModel: vm)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PIECES ON HAND'), findsOneWidget);
    expect(find.text('At a glance'), findsOneWidget);
    expect(find.text('Recent Transactions'), findsOneWidget);
    // Signed out: no inventory:view or sales_order:view.
    expect(find.text('Low Stock Items'), findsNothing);
    expect(find.text("Today's sales"), findsNothing);
    expect(inventory.calls, isEmpty);
    expect(orders.searches, isEmpty);
  });
}
