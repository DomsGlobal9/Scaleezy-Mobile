import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/shop/shop_context.dart';
import 'package:scaleezy/features/picking/presentation/picking_screen.dart';
import 'package:scaleezy/features/picking/presentation/view_models/pick_orders_view_model.dart';
import 'package:scaleezy/features/picking/presentation/view_models/pick_walk_view_model.dart';
import 'package:scaleezy/features/shelves/presentation/shelves_screen.dart';
import 'package:scaleezy/features/shelves/presentation/view_models/shelves_view_model.dart';

import '../shelves/shelves_fakes.dart' show FakeShelfRepository, treeOf;
import 'picking_fakes.dart';

Widget scoped(Widget home, {Set<String> can = const {}}) => SessionScope(
  session: FakeSession(can),
  child: ShopScope(
    shop: ShopContext(offlineClient()),
    child: MaterialApp(home: home),
  ),
);

void tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('orders screen lists the orders and chooses them', (
    tester,
  ) async {
    tallScreen(tester);
    final repo = FakePickingRepository(
      orders: (_) async => [order('o1', pieces: 3), order('o2')],
    );
    final vm = PickOrdersViewModel(repo)..start(store('L1'), const []);
    await tester.pumpWidget(scoped(PickOrdersScreen(viewModel: vm)));
    await tester.pumpAndSettle();

    expect(find.text('Store L1'), findsOneWidget);
    expect(find.text('SO-o1'), findsOneWidget);
    expect(find.text('Asha • Counter'), findsNWidgets(2));
    expect(find.text('Choose the orders to pick'), findsOneWidget);

    await tester.tap(find.text('SO-o1'));
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
    )..start(store('L1'), const []);
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
      )..start(store('L1'), const []);
      await tester.pumpWidget(scoped(ShelvesScreen(viewModel: vm), can: can));
      await tester.pumpAndSettle();
    }

    await open({'shelf:view'});
    expect(find.text('Pick orders'), findsNothing);

    await open({'shelf:view', 'shelf:putaway'});
    expect(find.text('Pick orders'), findsOneWidget);
  });
}
