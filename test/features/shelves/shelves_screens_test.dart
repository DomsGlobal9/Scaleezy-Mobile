import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/shop/shop_context.dart';
import 'package:scaleezy/core/shop/shop_models.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/core/widgets/no_access_screen.dart';
import 'package:scaleezy/features/shelves/data/shelf_models.dart';
import 'package:scaleezy/features/shelves/presentation/shelves_screen.dart';
import 'package:scaleezy/features/shelves/presentation/view_models/find_piece_view_model.dart';
import 'package:scaleezy/features/shelves/presentation/view_models/shelves_view_model.dart';
import 'package:scaleezy/features/shelves/presentation/view_models/spot_view_model.dart';
import 'package:scaleezy/features/shelves/presentation/view_models/waiting_to_shelve_view_model.dart';

import 'shelves_fakes.dart';

/// A shop whose selected store is [at] (none when null).
ShopContext shopAt(StockLocation? at) {
  final shop = ShopContext(offlineClient());
  if (at != null) shop.selectLocation(at);
  return shop;
}

Widget scoped(Widget home, {ShopContext? shop, ThemeData? theme}) =>
    SessionScope(
      session: AuthSession(offlineClient()),
      child: ShopScope(
        shop: shop ?? shopAt(store('L1')),
        child: MaterialApp(theme: theme ?? AppTheme.light, home: home),
      ),
    );

void tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

WhereItem whereItem() => WhereItem(
  item: item('v1', title: 'Banarasi'),
  places: [
    const WherePlace(
      locationId: 'L1',
      location: 'Store L1',
      total: 5,
      held: 1,
      usesShelves: true,
      shelves: [
        ShelfPlace(
          spotId: 's1',
          address: 'R1-S1',
          isShopFloor: true,
          quantity: 3,
        ),
        ShelfPlace(spotId: 's2', address: 'B1-S1', quantity: 1),
      ],
      notShelved: 1,
    ),
  ],
);

void main() {
  testWidgets('shelves screen shows the selected store\'s tree', (
    tester,
  ) async {
    tallScreen(tester);
    final repo = FakeShelfRepository(
      tree: (id) async => treeOf(id, [
        shelf('r1', children: [shelf('s1', name: 'Silk top', pieces: 4)]),
      ]),
    );
    final vm = ShelvesViewModel(repo);
    await tester.pumpWidget(scoped(ShelvesScreen(viewModel: vm)));
    await tester.pumpAndSettle();

    expect(find.text('Store L1'), findsOneWidget);
    expect(find.text('7 of 10 pieces'), findsOneWidget);
    expect(find.text('3 waiting to be put away'), findsOneWidget);
    expect(find.text('Silk top'), findsNothing);

    // A rack opens out to show its shelves.
    await tester.tap(find.text('R1'));
    await tester.pumpAndSettle();
    expect(find.text('Silk top'), findsOneWidget);
    expect(repo.calls, ['tree L1']);
  });

  testWidgets('switching the app\'s store reloads the shelves', (tester) async {
    tallScreen(tester);
    final repo = FakeShelfRepository(tree: (id) async => treeOf(id, []));
    final shop = shopAt(store('L1'));
    await tester.pumpWidget(
      scoped(ShelvesScreen(viewModel: ShelvesViewModel(repo)), shop: shop),
    );
    await tester.pumpAndSettle();

    shop.selectLocation(store('L2'));
    await tester.pumpAndSettle();

    expect(find.text('Store L2'), findsOneWidget);
    expect(repo.calls, ['tree L1', 'tree L2']);
  });

  testWidgets('shelves screen explains when there is no store', (tester) async {
    final vm = ShelvesViewModel(FakeShelfRepository());
    await tester.pumpWidget(
      scoped(ShelvesScreen(viewModel: vm), shop: shopAt(null)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No store is set up yet, so there are no shelves to show.'),
      findsOneWidget,
    );
  });

  testWidgets('a 403 shows no access instead of an error', (tester) async {
    tallScreen(tester);
    final vm = ShelvesViewModel(
      FakeShelfRepository(
        tree: (_) async =>
            throw const ApiException('Not allowed.', statusCode: 403),
      ),
    );
    await tester.pumpWidget(scoped(ShelvesScreen(viewModel: vm)));
    await tester.pumpAndSettle();

    expect(find.byType(NoAccessView), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('a shelf lists its pieces', (tester) async {
    final repo = FakeShelfRepository(
      spotAnswer: (id) async =>
          spotContents(id, items: [item('v1', title: 'Banarasi', quantity: 4)]),
    );
    final vm = SpotViewModel('s1', repo);
    await tester.pumpWidget(scoped(SpotScreen(spotId: 's1', viewModel: vm)));
    await tester.pumpAndSettle();

    expect(find.text('Banarasi'), findsOneWidget);
    expect(find.text('×4'), findsOneWidget);
    // Signed out here, so moving is not offered.
    expect(find.byTooltip('Move'), findsNothing);
  });

  testWidgets('where-is-it searches the selected store and every location', (
    tester,
  ) async {
    tallScreen(tester);
    final repo = FakeShelfRepository(find: (_) async => [whereItem()]);
    final vm = FindPieceViewModel(repo: repo);
    await tester.pumpWidget(
      scoped(FindPieceScreen(initialQuery: 'saree', viewModel: vm)),
    );
    await tester.pumpAndSettle();

    expect(repo.calls, ['find saree @L1']);
    expect(find.text('R1-S1'), findsOneWidget);
    expect(find.text('Shop floor'), findsOneWidget);
    expect(find.text('Back room'), findsOneWidget);
    expect(find.text('5 pieces here · 1 held for orders'), findsOneWidget);

    await tester.tap(find.text('Look in every location, not just Store L1'));
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'find saree @null');
  });

  testWidgets('where-is-it says when nothing matches', (tester) async {
    final vm = FindPieceViewModel(
      repo: FakeShelfRepository(find: (_) async => const []),
    );
    await tester.pumpWidget(
      scoped(FindPieceScreen(initialQuery: 'zzz', viewModel: vm)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nothing matches "zzz"'), findsOneWidget);
  });

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets('shelf screens draw in ${theme.brightness.name}', (
      tester,
    ) async {
      tallScreen(tester);
      final repo = FakeShelfRepository(
        tree: (id) async => treeOf(id, [
          shelf('r1', children: [shelf('s1', pieces: 4)]),
        ]),
        spotAnswer: (id) async => spotContents(id, items: [item('v1')]),
        find: (_) async => [whereItem()],
        waiting: () async => [
          NotShelvedItem(item: item('v1'), total: 4, notShelved: 2),
        ],
      );
      Future<void> show(Widget screen) async {
        await tester.pumpWidget(scoped(screen, theme: theme));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      await show(ShelvesScreen(viewModel: ShelvesViewModel(repo)));
      await show(
        SpotScreen(spotId: 's1', viewModel: SpotViewModel('s1', repo)),
      );
      await show(
        FindPieceScreen(
          initialQuery: 'saree',
          viewModel: FindPieceViewModel(repo: repo),
        ),
      );
      await show(
        WaitingToShelveScreen(
          locationId: 'L1',
          locationName: 'Store L1',
          viewModel: WaitingToShelveViewModel('L1', repo),
        ),
      );
      expect(find.text('2 pieces in Store L1'), findsOneWidget);
    });
  }
}
