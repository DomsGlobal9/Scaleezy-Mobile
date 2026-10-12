import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/shop/shop_context.dart';

import '../../support/pump.dart';
import '../../support/roles.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/features/picking/presentation/picking_screen.dart';
import 'package:scaleezy/features/picking/presentation/view_models/pick_orders_view_model.dart';
import 'package:scaleezy/features/picking/presentation/view_models/pick_walk_view_model.dart';
import 'package:scaleezy/features/shelves/presentation/shelves_screen.dart';
import 'package:scaleezy/features/shelves/presentation/view_models/shelves_view_model.dart';

import '../shelves/shelves_fakes.dart' show FakeShelfRepository, treeOf;
import 'picking_fakes.dart';

Widget scoped(Widget home, {Set<String> can = const {}, ThemeData? theme}) =>
    SessionScope(
      session: TestSession.as(can),
      child: ShopScope(
        // The app's selected store is L1.
        shop: TestShop(stores: [store('L1')]),
        child: MaterialApp(theme: theme ?? AppTheme.light, home: home),
      ),
    );

void tallScreen(WidgetTester tester) =>
    setPhone(tester, width: 400, height: 1600);

void main() {
  testWidgets('orders screen lists the orders and chooses them', (
    tester,
  ) async {
    tallScreen(tester);
    final repo = FakePickingRepository(
      orders: (_) async => [order('o1', pieces: 3), order('o2')],
    );
    final vm = PickOrdersViewModel(repo);
    await tester.pumpWidget(scoped(PickOrdersScreen(viewModel: vm)));
    await tester.pumpAndSettle();

    expect(repo.calls, ['orders L1']);
    expect(find.text('Waiting to go out from Store L1'), findsOneWidget);
    expect(find.text('SO-o1 · Asha · Counter'), findsOneWidget);
    expect(find.text('Choose the orders to pick'), findsOneWidget);

    await tester.tap(find.text('SO-o1 · Asha · Counter'));
    await tester.pumpAndSettle();
    expect(vm.selected, ['o1']);
    expect(find.text('Pick 1 order'), findsOneWidget);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select 2'));
    await tester.pumpAndSettle();
    expect(find.text('Pick 2 orders'), findsOneWidget);
  });

  testWidgets('orders screen says when nothing is waiting', (tester) async {
    final vm = PickOrdersViewModel(
      FakePickingRepository(orders: (_) async => []),
    );
    await tester.pumpWidget(scoped(PickOrdersScreen(viewModel: vm)));
    await tester.pumpAndSettle();

    expect(find.text('Nothing waiting to go out'), findsOneWidget);
  });

  testWidgets('the walk ticks off pieces and sends them out', (tester) async {
    tallScreen(tester);
    final repo = FakePickingRepository(
      list: (_) async => listOf([
        stop('sp1', [pick('o1', 'i1', 2)]),
      ]),
      send: (_) async {},
    );
    final vm = PickWalkViewModel(
      locationId: 'L1',
      orderIds: const ['o1'],
      repo: repo,
    );
    // Opened from another screen, which it returns to once the order is sent.
    await tester.pumpWidget(
      scoped(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<bool>(
                  builder: (_) => PickWalkScreen(
                    locationId: 'L1',
                    orderIds: const ['o1'],
                    viewModel: vm,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
        can: {'shelf:putaway', 'dispatch:create'},
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('SP1'), findsOneWidget);
    expect(find.text('0 of 1 picked'), findsOneWidget);
    expect(find.text('Next: go to SP1, then scan the item.'), findsOneWidget);
    expect(find.text('Not here'), findsOneWidget);

    await tester.tap(find.text('Picked'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 1 picked'), findsOneWidget);
    expect(find.text('Everything is picked.'), findsOneWidget);

    await tester.tap(find.text('Send out 2 pieces'));
    await tester.pumpAndSettle();
    expect(find.text('Send out 2 pieces?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Send out'));
    await tester.pumpAndSettle();

    expect(repo.calls.last, 'dispatch o1');
    expect(find.text('1 order sent out.'), findsOneWidget);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('without dispatch:create the walk cannot send out', (
    tester,
  ) async {
    tallScreen(tester);
    final vm = PickWalkViewModel(
      locationId: 'L1',
      orderIds: const ['o1'],
      repo: FakePickingRepository(
        list: (_) async => listOf([
          stop('sp1', [pick('o1', 'i1', 1)]),
        ]),
      ),
    );
    await tester.pumpWidget(
      scoped(
        PickWalkScreen(locationId: 'L1', orderIds: const ['o1'], viewModel: vm),
        can: {'shelf:putaway'},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Send out'), findsNothing);
    expect(
      find.textContaining('Someone who can send orders out finishes this.'),
      findsOneWidget,
    );
  });

  testWidgets('the shelves screen offers picking only with shelf:putaway', (
    tester,
  ) async {
    tallScreen(tester);
    Future<void> open(Set<String> can) async {
      final vm = ShelvesViewModel(
        FakeShelfRepository(tree: (id) async => treeOf(id, [])),
      );
      await tester.pumpWidget(scoped(ShelvesScreen(viewModel: vm), can: can));
      await tester.pumpAndSettle();
    }

    await open({'shelf:view'});
    expect(find.text('Pick orders'), findsNothing);

    await open({'shelf:view', 'shelf:putaway'});
    expect(find.text('Pick orders'), findsOneWidget);
  });

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets('picking screens draw in ${theme.brightness.name}', (
      tester,
    ) async {
      tallScreen(tester);
      final repo = FakePickingRepository(
        orders: (_) async => [order('o1', status: 'PARTIALLY_DISPATCHED')],
        list: (_) async => listOf(
          [
            stop('sp1', [pick('o1', 'i1', 2)]),
          ],
          notShelved: [pick('o1', 'i2', 1, v: 'v2')],
          short: [pick('o1', 'i3', 1, v: 'v3')],
        ),
      );
      await tester.pumpWidget(
        scoped(
          PickOrdersScreen(viewModel: PickOrdersViewModel(repo)),
          can: {'shelf:putaway'},
          theme: theme,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('partly sent'), findsOneWidget);

      await tester.pumpWidget(
        scoped(
          PickWalkScreen(
            locationId: 'L1',
            orderIds: const ['o1'],
            viewModel: PickWalkViewModel(
              locationId: 'L1',
              orderIds: const ['o1'],
              repo: repo,
            ),
          ),
          can: {'shelf:putaway', 'dispatch:create'},
          theme: theme,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Back room'), findsOneWidget);
      expect(find.text('Not enough here'), findsOneWidget);
    });
  }
}
