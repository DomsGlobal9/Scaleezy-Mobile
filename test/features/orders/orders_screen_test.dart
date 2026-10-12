import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:scaleezy/app/router.dart';
import 'package:scaleezy/core/shop/shop_context.dart';
import 'package:scaleezy/features/orders/presentation/order_detail_screen.dart';
import 'package:scaleezy/features/orders/presentation/orders_screen.dart';
import 'package:scaleezy/features/orders/presentation/view_models/order_details_view_model.dart';
import 'package:scaleezy/features/orders/presentation/view_models/orders_view_model.dart';

import '../products/products_fakes.dart' show offlineClient;
import 'orders_fakes.dart';

/// The orders list and its detail page at their app paths, both answered by [repo].
Widget ordersApp(FakeOrderRepository repo) => ShopScope(
  shop: ShopContext(offlineClient()),
  child: MaterialApp.router(
    routerConfig: GoRouter(
      initialLocation: Paths.orders,
      routes: [
        GoRoute(
          path: Paths.orders,
          builder: (_, _) => OrdersScreen(viewModel: OrdersViewModel(repo)),
          routes: [
            GoRoute(
              path: ':id',
              builder: (_, state) => OrderDetailScreen(
                orderId: state.pathParameters['id']!,
                viewModel: OrderDetailsViewModel(
                  state.pathParameters['id']!,
                  repo,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  ),
);

void main() {
  testWidgets('orders screen lists, filters and opens an order', (
    tester,
  ) async {
    final repo = FakeOrderRepository(
      answer: () async => [
        order('a', customer: 'Priya Sharma'),
        order('b', customer: 'Ravi Kumar', status: 'DRAFT'),
      ],
      detail: (id) async => orderDetail(id),
    );
    await tester.pumpWidget(ordersApp(repo));
    await tester.pumpAndSettle();

    expect(find.text('Priya Sharma'), findsOneWidget);
    expect(find.text('Ravi Kumar'), findsOneWidget);

    await tester.tap(find.text('draft'));
    await tester.pumpAndSettle();
    expect(find.text('Priya Sharma'), findsNothing);
    expect(find.text('Ravi Kumar'), findsOneWidget);

    await tester.tap(find.text('Ravi Kumar'));
    await tester.pumpAndSettle();
    expect(find.text('SO-b'), findsOneWidget);
    expect(find.text('Banarasi Saree'), findsOneWidget);
    // Not a counter bill: no receipt, as on the web.
    expect(find.text('Receipt'), findsNothing);

    // Back from the page returns to the list as it was left.
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Banarasi Saree'), findsNothing);
    expect(find.text('Ravi Kumar'), findsOneWidget);
    expect(find.text('Priya Sharma'), findsNothing);
  });

  testWidgets('a counter bill offers its receipt', (tester) async {
    final repo = FakeOrderRepository(
      answer: () async => [
        order('a', customer: 'Priya Sharma', atCounter: true),
      ],
      detail: (id) async => orderDetail(id, atCounter: true),
    );
    await tester.pumpWidget(ordersApp(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Priya Sharma'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(OutlinedButton, 'Receipt'), findsOneWidget);
  });
}
