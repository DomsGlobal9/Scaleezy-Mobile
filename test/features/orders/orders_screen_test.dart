import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/shop/shop_context.dart';
import 'package:scaleezy/features/orders/presentation/orders_screen.dart';
import 'package:scaleezy/features/orders/presentation/view_models/orders_view_model.dart';

import '../products/products_fakes.dart' show offlineClient;
import 'orders_fakes.dart';

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
    final vm = OrdersViewModel(repo);
    await tester.pumpWidget(
      ShopScope(
        shop: ShopContext(offlineClient()),
        child: MaterialApp(home: OrdersScreen(viewModel: vm)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Priya Sharma'), findsOneWidget);
    expect(find.text('Ravi Kumar'), findsOneWidget);

    await tester.tap(find.text('draft'));
    await tester.pumpAndSettle();
    expect(find.text('Priya Sharma'), findsNothing);
    expect(find.text('Ravi Kumar'), findsOneWidget);

    await tester.tap(find.text('Ravi Kumar'));
    await tester.pumpAndSettle();
    expect(find.text('Banarasi Saree'), findsOneWidget);
    // Not a counter bill: no receipt, as on the web.
    expect(find.text('Receipt'), findsNothing);

    // Closing the sheet disposes its view model mid-animation without complaint.
    Navigator.of(tester.element(find.text('Banarasi Saree'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('Banarasi Saree'), findsNothing);
  });

  testWidgets('a counter bill offers its receipt', (tester) async {
    final repo = FakeOrderRepository(
      answer: () async => [
        order('a', customer: 'Priya Sharma', atCounter: true),
      ],
      detail: (id) async => orderDetail(id, atCounter: true),
    );
    await tester.pumpWidget(
      ShopScope(
        shop: ShopContext(offlineClient()),
        child: MaterialApp(
          home: OrdersScreen(viewModel: OrdersViewModel(repo)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Priya Sharma'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(OutlinedButton, 'Receipt'), findsOneWidget);
  });
}
