import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/shop/shop_context.dart';
import 'package:scaleezy/core/shop/shop_models.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/features/shell/presentation/more_screen.dart';
import 'package:scaleezy/features/transfers/presentation/transfer_screen.dart';
import 'package:scaleezy/features/transfers/presentation/view_models/transfer_view_model.dart';

import 'transfers_fakes.dart';

/// A signed-in role holding exactly [perms].
class _Role extends AuthSession {
  _Role(this.perms) : super(offlineClient());
  final Set<String> perms;

  @override
  bool can(String permission) => perms.contains(permission);
}

/// A shop with these stores, loaded already.
class _Shop extends ShopContext {
  _Shop(this._stores) : super(offlineClient());
  final List<StockLocation> _stores;

  @override
  List<StockLocation> get locations => _stores;
}

Widget scoped(
  Widget home, {
  Set<String> perms = const {},
  List<StockLocation> stores = const [],
  ThemeData? theme,
}) => SessionScope(
  session: _Role(perms),
  child: ShopScope(
    shop: _Shop(stores),
    child: MaterialApp(theme: theme ?? AppTheme.light, home: home),
  ),
);

void main() {
  testWidgets('search, add, confirm in plain words, then the result', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeTransferRepository(
      stock: (_, _) async => [stock('v1', title: 'Silk saree', quantity: 2)],
      send: () async {},
    );
    // Started already, so the screen does not pick stores from the (empty) shop.
    final vm = TransferViewModel(
      repo: repo,
      products: FakeProductRepository((_) async => []),
    )..start(store('L1'), [store('L1'), store('L2')]);
    await tester.pumpWidget(scoped(TransferScreen(viewModel: vm)));
    await tester.pumpAndSettle();
    expect(find.text('Add items to move'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'silk');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(find.text('2 at Store L1'), findsOneWidget);
    await tester.tap(find.text('Silk saree'));
    await tester.pumpAndSettle();

    // One piece listed; the stepper stops at the two the store has.
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    expect(vm.qty('v1'), 2);

    await tester.tap(find.text('Move 2 pieces'));
    await tester.pumpAndSettle();
    expect(
      find.text('Move 2 pieces from Store L1 to Store L2?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Move now'));
    await tester.pumpAndSettle();

    expect(find.text('Moved 2 pieces'), findsOneWidget);
    expect(repo.sent.single['quantities'], {'v1': 2});
    // Putting away needs shelf:putaway, which this role lacks.
    expect(find.textContaining('Put away at'), findsNothing);
  });

  testWidgets('More offers the move only with the permission and two stores', (
    tester,
  ) async {
    Future<void> more(Set<String> perms, List<StockLocation> stores) async {
      await tester.pumpWidget(
        scoped(const MoreScreen(), perms: perms, stores: stores),
      );
      // Cards rebuilt by a new list start their entrance after a delay.
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }

    final two = [store('L1'), store('L2'), store('W', type: 'ONLINE')];
    await more({'inventory:transfer'}, two);
    expect(find.text('Move stock'), findsOneWidget);

    await more(
      {'inventory:transfer'},
      [store('L1'), store('W', type: 'ONLINE')],
    );
    expect(find.text('Move stock'), findsNothing);

    await more({}, two);
    expect(find.text('Move stock'), findsNothing);
  });

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets('draws in ${theme.brightness.name}, list and result', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final vm = TransferViewModel(
        repo: FakeTransferRepository(
          stock: (_, _) async => [stock('v1', title: 'Silk saree')],
          send: () async {},
        ),
        products: FakeProductRepository((_) async => []),
      )..start(store('L1'), [store('L1'), store('L2')]);
      await tester.pumpWidget(
        scoped(
          TransferScreen(viewModel: vm),
          perms: {'shelf:putaway'},
          theme: theme,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Store L1'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.enterText(find.byType(TextField).first, 'silk');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Silk saree'));
      await tester.pumpAndSettle();
      expect(await vm.move(''), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('Put away at Store L2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
