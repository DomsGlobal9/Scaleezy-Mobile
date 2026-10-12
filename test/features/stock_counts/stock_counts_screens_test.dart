import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/shop/shop_context.dart';
import 'package:scaleezy/features/stock_counts/presentation/stock_counts_screen.dart';
import 'package:scaleezy/features/stock_counts/presentation/view_models/stock_count_view_model.dart';
import 'package:scaleezy/features/stock_counts/presentation/view_models/stock_counts_view_model.dart';

import '../auth/auth_fakes.dart';
import 'stock_counts_fakes.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    bool owner = true,
  }) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      SessionScope(
        session: FakeSession(person(owner: owner)),
        child: ShopScope(
          shop: FakeShopContext([store('L1'), store('L2')]),
          child: MaterialApp(home: home),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('counts list', () {
    final counts = [
      count('1', name: 'Kids rack', status: 'IN_PROGRESS', items: 12),
      count(
        '2',
        name: 'September Full Count',
        status: 'COMPLETED',
        items: 40,
        matched: 30,
        adjusted: 4,
        accuracy: '88.24',
      ),
    ];

    testWidgets('shows each count with its store, status and progress', (
      tester,
    ) async {
      final vm = StockCountsViewModel(
        FakeStockCountRepository(list: () async => counts),
      );
      await pump(tester, StockCountsScreen(viewModel: vm));

      expect(find.text('1 still open'), findsOneWidget);
      expect(find.text('Kids rack'), findsOneWidget);
      expect(find.text('IN PROGRESS'), findsOneWidget);
      expect(find.text('12 items to count'), findsOneWidget);
      expect(find.text('Store L1 • made 1 Oct'), findsNWidgets(2));
      expect(find.text('34 of 40 counted'), findsOneWidget);
      expect(find.text('88.2% matched'), findsOneWidget);
      expect(find.text('New count'), findsOneWidget);
    });

    testWidgets('New count is hidden without stock_count:create', (
      tester,
    ) async {
      final vm = StockCountsViewModel(
        FakeStockCountRepository(list: () async => counts),
      );
      await pump(tester, StockCountsScreen(viewModel: vm), owner: false);
      expect(find.text('New count'), findsNothing);
    });

    testWidgets('a refused new count shows the server message in the sheet', (
      tester,
    ) async {
      final repo = FakeStockCountRepository(
        list: () async => counts,
        create: () async => throw const ApiException(
          'L2 is switched off, so it cannot be counted.',
        ),
      );
      await pump(
        tester,
        StockCountsScreen(viewModel: StockCountsViewModel(repo)),
      );

      await tester.tap(find.text('New count'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Store L2'));
      await tester.tap(find.text('Kids'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create count'));
      await tester.pumpAndSettle();

      expect(repo.calls.last, endsWith(' Full Count L2 KIDS'));
      expect(
        find.text('L2 is switched off, so it cannot be counted.'),
        findsOneWidget,
      );
    });
  });

  group('one count', () {
    Future<(StockCountViewModel, FakeStockCountRepository)> open(
      WidgetTester tester, {
      bool owner = true,
      String status = 'IN_PROGRESS',
    }) async {
      final repo = FakeStockCountRepository(
        one: () async => detail(status: status),
        save: (id, n) async => savedLine(id, expected: 4, counted: n),
      );
      final vm = StockCountViewModel('c1', repo);
      await pump(
        tester,
        StockCountScreen(countId: 'c1', viewModel: vm),
        owner: owner,
      );
      return (vm, repo);
    }

    testWidgets('shows every line with expected and counted', (tester) async {
      await open(tester);

      expect(find.text('October 2026 Full Count'), findsOneWidget);
      expect(find.text('Store L1'), findsOneWidget);
      expect(find.text('Cotton Kurta'), findsOneWidget);
      expect(find.text('not counted'), findsOneWidget);
      expect(find.text('expected 10'), findsOneWidget);
      expect(find.byTooltip('Add one piece'), findsNWidgets(3));
      expect(find.text('Scan'), findsOneWidget);
      expect(find.text('Finish count'), findsOneWidget);
      expect(find.text('Cancel count'), findsOneWidget);

      await tester.tap(find.text('Differences  1'));
      await tester.pumpAndSettle();
      expect(find.text('Cotton Kurta'), findsNothing);
      expect(find.text('Linen Shirt'), findsOneWidget);
    });

    testWidgets('typing a count saves it and shows it on the line', (
      tester,
    ) async {
      final (_, repo) = await open(tester);

      await tester.tap(find.text('Cotton Kurta'));
      await tester.pumpAndSettle();
      expect(find.text('Expected 4 on the books'), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(TextField),
        ),
        '6',
      );
      await tester.pump();
      await tester.tap(find.text('Save: 6 counted'));
      await tester.pumpAndSettle();

      expect(repo.calls.last, 'set c1 a 6');
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('not counted'), findsNothing);
      expect(find.text('+2'), findsOneWidget);
    });

    testWidgets('+1 on a line saves one more piece', (tester) async {
      final (_, repo) = await open(tester);
      await tester.tap(find.byTooltip('Add one piece').first);
      await tester.pumpAndSettle();
      expect(repo.calls.last, 'set c1 a 1');
    });

    testWidgets('a staff member cannot cancel, count or finish', (
      tester,
    ) async {
      await open(tester, owner: false);
      expect(find.text('Cotton Kurta'), findsOneWidget);
      expect(find.text('Cancel count'), findsNothing);
      expect(find.text('Scan'), findsNothing);
      expect(find.text('Finish count'), findsNothing);
      expect(find.byTooltip('Add one piece'), findsNothing);
    });

    testWidgets('a draft offers Start counting and no counting', (
      tester,
    ) async {
      await open(tester, status: 'DRAFT');
      expect(find.text('Start counting'), findsOneWidget);
      expect(find.text('Scan'), findsNothing);
      expect(find.byTooltip('Add one piece'), findsNothing);
    });
  });
}
