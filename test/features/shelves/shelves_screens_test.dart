import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/shop/shop_context.dart';
import 'package:scaleezy/features/shelves/presentation/shelves_screen.dart';
import 'package:scaleezy/features/shelves/presentation/view_models/shelves_view_model.dart';
import 'package:scaleezy/features/shelves/presentation/view_models/spot_view_model.dart';

import 'shelves_fakes.dart';

Widget scoped(Widget home) => SessionScope(
  session: AuthSession(offlineClient()),
  child: ShopScope(
    shop: ShopContext(offlineClient()),
    child: MaterialApp(home: home),
  ),
);

void main() {
  testWidgets('shelves screen shows the tree its view model loads', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeShelfRepository(
      tree: (id) async => treeOf(id, [
        shelf('r1', children: [shelf('s1', name: 'Silk top', pieces: 4)]),
      ]),
    );
    // Started on a store already, so the screen does not pick one from the (empty) shop.
    final vm = ShelvesViewModel(repo)..start(store('L1'), const []);
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

  testWidgets('shelves screen explains when there is no store', (tester) async {
    final vm = ShelvesViewModel(FakeShelfRepository());
    await tester.pumpWidget(scoped(ShelvesScreen(viewModel: vm)));
    await tester.pumpAndSettle();

    expect(
      find.text('No store is set up yet, so there are no shelves to show.'),
      findsOneWidget,
    );
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
}
