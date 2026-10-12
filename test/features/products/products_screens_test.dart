import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/models/paged.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/shop/shop_context.dart';
import 'package:scaleezy/features/products/presentation/product_detail_screen.dart';
import 'package:scaleezy/features/products/presentation/products_screen.dart';
import 'package:scaleezy/features/products/presentation/view_models/product_detail_view_model.dart';
import 'package:scaleezy/features/products/presentation/view_models/products_view_model.dart';

import 'products_fakes.dart';

void main() {
  testWidgets('products screen shows what its view model loads', (
    tester,
  ) async {
    final repo = FakeProductRepository(
      answer: (_) async => Paged(
        items: [
          product('a', title: 'Banarasi Saree'),
          product('b', title: 'Silk Kurta'),
        ],
        page: 1,
        pages: 1,
        total: 2,
      ),
    );
    final vm = ProductsViewModel(repo);
    await tester.pumpWidget(
      ShopScope(
        shop: ShopContext(offlineClient()),
        child: MaterialApp(home: ProductsScreen(viewModel: vm)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Banarasi Saree'), findsOneWidget);
    expect(find.text('2 products'), findsOneWidget);

    await tester.tap(find.text('Men'));
    await tester.pumpAndSettle();
    expect(repo.calls.last['category'], 'MEN');
  });

  testWidgets('product detail filters sizes by colour', (tester) async {
    // Tall enough that the cards under the 360px photo are built.
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final saree = product('p1', title: 'Banarasi Saree');
    final vm = ProductDetailViewModel(
      saree,
      products: FakeProductRepository(
        variants: () async => [
          variant('v1', colour: 'Red', size: 'S'),
          variant('v2', colour: 'Blue', size: 'L'),
        ],
      ),
      inventory: FakeInventoryRepository(),
    );
    await tester.pumpWidget(
      SessionScope(
        session: AuthSession(offlineClient()),
        child: MaterialApp(
          home: ProductDetailScreen(product: saree, viewModel: vm),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Red • Size S'), findsOneWidget);
    expect(find.text('Blue • Size L'), findsOneWidget);

    await tester.tap(find.text('Blue'));
    await tester.pumpAndSettle();
    expect(find.text('Red • Size S'), findsNothing);
    expect(find.text('Blue • Size L'), findsOneWidget);
  });
}
