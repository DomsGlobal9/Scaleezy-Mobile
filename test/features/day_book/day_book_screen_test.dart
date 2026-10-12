import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/shop/shop_context.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/features/day_book/presentation/day_book_screen.dart';
import 'package:scaleezy/features/day_book/presentation/view_models/day_book_view_model.dart';

import '../products/products_fakes.dart' show offlineClient;
import 'day_book_fakes.dart';

Future<FakeDayBookRepository> _pump(
  WidgetTester tester, {
  bool cost = true,
  ThemeData? theme,
}) async {
  tester.view.physicalSize = const Size(360, 6000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = FakeDayBookRepository(
    (date) async => dayBook(
      date: date ?? '2026-10-12',
      inProgress: date == null,
      cost: cost,
    ),
  );
  await tester.pumpWidget(
    ShopScope(
      shop: ShopContext(offlineClient()),
      child: MaterialApp(
        theme: theme ?? AppTheme.light,
        home: DayBookScreen(viewModel: DayBookViewModel(repo)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('day book shows the day, its sales, money and stock', (
    tester,
  ) async {
    final repo = await _pump(tester);

    expect(repo.calls, [(null, null)]);
    expect(find.text('Day book'), findsOneWidget);
    expect(find.text('Monday, 12 October 2026'), findsOneWidget);
    expect(find.text('STILL RUNNING'), findsOneWidget);

    expect(find.text('OPENING STOCK'), findsOneWidget);
    expect(find.text('+67'), findsOneWidget);
    expect(find.textContaining('Every piece is accounted for'), findsOneWidget);

    expect(find.text('Sales dispatched'), findsOneWidget);
    expect(find.text('₹11,530'), findsOneWidget);
    expect(find.text('Sales you keep'), findsOneWidget);
    expect(find.text('What it cost you'), findsOneWidget);
    expect(find.text('₹5,680'), findsOneWidget);
    expect(find.text('Profit'), findsOneWidget);
    expect(find.text('₹3,167.61'), findsOneWidget);
    expect(find.textContaining('Profit is worked out on'), findsOneWidget);

    expect(find.text('Money at the counter'), findsOneWidget);
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('Paid back ₹1,200'), findsOneWidget);
    expect(find.text('UPI'), findsOneWidget);
    expect(find.text('Store credit'), findsOneWidget);

    expect(find.text('Purchase received'), findsOneWidget);
    expect(find.text('Sold and dispatched'), findsOneWidget);
    expect(find.text('Main Store (MS)'), findsOneWidget);
    expect(find.text('Cotton Kurta KUR-BLU-L'), findsOneWidget);

    // Today has nothing after it; the day before is one press away.
    await tester.tap(find.byTooltip('Next day'));
    await tester.pumpAndSettle();
    expect(repo.calls, hasLength(1));
    await tester.tap(find.byTooltip('Previous day'));
    await tester.pumpAndSettle();
    expect(repo.calls.last, ('2026-10-11', null));
    expect(find.text('Sunday, 11 October 2026'), findsOneWidget);
    expect(find.text('STILL RUNNING'), findsNothing);
  });

  testWidgets('without cost access there is no cost or profit', (tester) async {
    await _pump(tester, cost: false);

    expect(find.text('Billed'), findsOneWidget);
    expect(find.text('What it cost you'), findsNothing);
    expect(find.text('Profit'), findsNothing);
    expect(find.textContaining('Profit is worked out on'), findsNothing);
  });

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets('day book draws in ${theme.brightness.name}', (tester) async {
      await _pump(tester, theme: theme);
      expect(tester.takeException(), isNull);
      expect(find.text('Stock for the day'), findsOneWidget);
    });
  }
}
