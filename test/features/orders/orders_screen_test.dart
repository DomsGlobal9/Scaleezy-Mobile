import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:scaleezy/app/router.dart';
import 'package:scaleezy/core/shop/shop_context.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/core/widgets/status_pill.dart';
import 'package:scaleezy/features/orders/presentation/order_detail_screen.dart';
import 'package:scaleezy/features/orders/presentation/orders_screen.dart';
import 'package:scaleezy/features/orders/presentation/view_models/order_details_view_model.dart';
import 'package:scaleezy/features/orders/presentation/view_models/orders_view_model.dart';

import '../products/products_fakes.dart' show offlineClient;
import 'orders_fakes.dart';

/// The orders list and its detail page at their app paths, both answered by [repo].
Widget ordersApp(FakeOrderRepository repo, {ThemeData? theme}) => ShopScope(
  shop: ShopContext(offlineClient()),
  child: MaterialApp.router(
    theme: theme ?? AppTheme.light,
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

    expect(find.textContaining('Priya Sharma'), findsOneWidget);
    expect(find.textContaining('Ravi Kumar'), findsOneWidget);
    expect(find.text('Order number, phone or name'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Draft'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Priya Sharma'), findsNothing);
    expect(find.textContaining('Ravi Kumar'), findsOneWidget);

    await tester.tap(find.text('SO-b'));
    await tester.pumpAndSettle();
    expect(find.text('Order SO-b'), findsOneWidget);
    expect(find.text('Banarasi Saree'), findsOneWidget);
    expect(find.text('Grand total'), findsOneWidget);
    // Not a counter bill: no receipt, as on the web.
    expect(find.text('Receipt'), findsNothing);

    // Back from the page returns to the list as it was left.
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Banarasi Saree'), findsNothing);
    expect(find.textContaining('Ravi Kumar'), findsOneWidget);
    expect(find.textContaining('Priya Sharma'), findsNothing);
  });

  testWidgets('rows carry the website\'s status and payment pills', (
    tester,
  ) async {
    final repo = FakeOrderRepository(
      answer: () async => [
        order(
          'a',
          status: 'PARTIALLY_DISPATCHED',
          atCounter: true,
          payment: {'status': 'PART_PAID', 'paid': 2000, 'due': 98},
        ),
        order(
          'b',
          sourceSystem: 'SCALEEZY_POS',
          payment: {'status': 'PAID', 'paid': 100, 'due': 0},
        ),
        order(
          'c',
          sourceSystem: 'SHOPIFY',
          payment: {'status': 'UNPAID', 'paid': 0, 'due': 100},
        ),
      ],
    );
    await tester.pumpWidget(ordersApp(repo));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(StatusPill, 'Partly sent'), findsOneWidget);
    expect(find.text('₹98 due'), findsOneWidget);
    expect(find.text('Paid'), findsOneWidget);
    expect(find.textContaining('POS till'), findsOneWidget);
    expect(find.textContaining('Shopify'), findsOneWidget);

    // Where from goes to the server.
    await tester.tap(find.byTooltip('Where from'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Counter').last);
    await tester.pumpAndSettle();
    expect(repo.sources.last, 'COUNTER');
  });

  testWidgets('a counter bill offers its receipt and shows its payments', (
    tester,
  ) async {
    final repo = FakeOrderRepository(
      answer: () async => [
        order('a', customer: 'Priya Sharma', atCounter: true),
      ],
      detail: (id) async => orderDetail(id, atCounter: true),
    );
    await tester.pumpWidget(ordersApp(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('SO-a'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(OutlinedButton, 'Receipt'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Payments'), 200);
    expect(find.text('No payment recorded.'), findsOneWidget);
  });

  testWidgets('a list that fails to load says so and offers a retry', (
    tester,
  ) async {
    final repo = FakeOrderRepository(answer: () async => throw Exception());
    await tester.pumpWidget(ordersApp(repo));
    await tester.pumpAndSettle();
    expect(find.text('Could not load orders.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets('list and order page draw in ${theme.brightness.name}', (
      tester,
    ) async {
      final repo = FakeOrderRepository(
        answer: () async => [
          order('a', atCounter: true, payment: {'status': 'PAID', 'paid': 1}),
          order('b', status: 'CANCELLED'),
        ],
        detail: (id) async => orderDetail(id, atCounter: true),
      );
      await tester.pumpWidget(ordersApp(repo, theme: theme));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('SO-a'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Order SO-a'), findsOneWidget);
    });
  }
}
