import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/models/paged.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/shop/shop_context.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/features/products/presentation/product_detail_screen.dart';
import 'package:scaleezy/features/products/presentation/products_screen.dart';
import 'package:scaleezy/features/products/presentation/view_models/product_detail_view_model.dart';
import 'package:scaleezy/features/products/presentation/view_models/products_view_model.dart';

import 'products_fakes.dart';

void main() {
  for (final theme in [AppTheme.light, AppTheme.dark]) {
    final mode = theme.brightness.name;

    testWidgets('products screen shows what its view model loads ($mode)', (
      tester,
    ) async {
      final repo = FakeProductRepository(
        answer: (_) async => Paged(
          items: [
            product('a', title: 'Banarasi Saree', totalUnits: 4),
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
          child: MaterialApp(
            theme: theme,
            home: ProductsScreen(viewModel: vm),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Banarasi Saree'), findsOneWidget);
      expect(find.text('2 products'), findsOneWidget);
      expect(find.text('4 in stock'), findsOneWidget);
      expect(find.text('Out of stock'), findsOneWidget);

      // The catalogue call failed, so the built-in categories are offered.
      await tester.tap(find.text('Men'));
      await tester.pumpAndSettle();
      expect(repo.calls.last['category'], 'MEN');

      await tester.tap(find.byTooltip('List'));
      await tester.pumpAndSettle();
      expect(find.text('Silk Kurta'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('products screen says when there are none ($mode)', (
      tester,
    ) async {
      final vm = ProductsViewModel(
        FakeProductRepository(
          answer: (_) async =>
              const Paged(items: [], page: 1, pages: 1, total: 0),
        ),
      );
      await tester.pumpWidget(
        ShopScope(
          shop: ShopContext(offlineClient()),
          child: MaterialApp(
            theme: theme,
            home: ProductsScreen(viewModel: vm),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No products added yet.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('product detail filters sizes by colour ($mode)', (
      tester,
    ) async {
      // Tall enough that the cards under the 360px photo are built.
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final saree = product('p1', title: 'Banarasi Saree');
      final vm = ProductDetailViewModel(
        saree,
        products: FakeProductRepository(
          variants: () async => [
            variant(
              'v1',
              colour: 'Red',
              size: 'S',
              costPrice: '900.00',
              averageCost: '841.50',
            ),
            variant('v2', colour: 'Blue', size: 'L', quantity: -2),
          ],
        ),
        inventory: FakeInventoryRepository(),
      );
      await tester.pumpWidget(
        SessionScope(
          session: AuthSession(offlineClient()),
          child: MaterialApp(
            theme: theme,
            home: ProductDetailScreen(product: saree, viewModel: vm),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Red • Size S'), findsOneWidget);
      expect(find.text('Blue • Size L'), findsOneWidget);
      expect(find.text('-2 · oversold'), findsOneWidget);
      expect(find.textContaining('You pay'), findsOneWidget);
      expect(find.textContaining('Average cost'), findsOneWidget);

      await tester.tap(find.text('Blue'));
      await tester.pumpAndSettle();
      expect(find.text('Red • Size S'), findsNothing);
      expect(find.text('Blue • Size L'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a refused product load shows no access, not a retry', (
    tester,
  ) async {
    final saree = product('p1');
    final vm = ProductDetailViewModel(
      saree,
      products: FakeProductRepository(
        variants: () async =>
            throw const ApiException('Not allowed.', statusCode: 403),
      ),
      inventory: FakeInventoryRepository(),
    );
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      SessionScope(
        session: AuthSession(offlineClient()),
        child: MaterialApp(
          theme: AppTheme.light,
          home: ProductDetailScreen(product: saree, viewModel: vm),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsNothing);
    expect(find.text('Not part of your role'), findsOneWidget);
  });
}
