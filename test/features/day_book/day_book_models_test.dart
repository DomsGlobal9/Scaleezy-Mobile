import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/features/day_book/data/day_book_models.dart';

import 'day_book_fakes.dart';

void main() {
  test('day book: one day with sales, a return and money at the counter', () {
    final b = dayBook();
    expect(b.date, '2026-10-12');
    expect(b.day, DateTime(2026, 10, 12));
    expect(b.inProgress, isTrue);
    expect(b.opening!.units, 120);
    expect(b.opening!.value, 180000);
    expect(b.closing!.units, 183);
    expect(b.balanced, isTrue);
    expect(b.valueMatches, isFalse);
    expect(b.valueGap, 3087.57);

    expect(b.cameIn.units, 67);
    expect(b.cameIn.value, 100500);
    expect(b.inLines.map((l) => l.label), [
      'Purchase received',
      'Customer returns',
    ]);
    expect(b.wentOut.units, 4);

    expect(b.dispatchCount, 2);
    expect(b.revenue, 11530);
    expect(b.gstCollected, 549.06);
    expect(b.returnedValue, 2240);
    expect(b.returnedUnits, 1);
    expect(b.netSales, 8847.61);
    // netCost: cost of what sold less what went back on the shelf.
    expect(b.cost, 5680);
    expect(b.profit, 3167.61);
    expect(b.hasSales, isTrue);
    expect(b.hasDeductions, isTrue);
    expect(b.dispatches.first.customer, 'Priya Sharma');
    expect(b.dispatches.last.customer, isNull);

    expect(b.taken, {'CASH': 4200, 'UPI': 6830.5, 'CREDIT': 300});
    expect(b.paidBack, {'CASH': 1200});
    expect(b.cashInDrawer, 3000);

    expect(b.byLocation.single.name, 'Main Store (MS)');
    expect(b.topMovers.single.unitsOut, 3);
    expect(b.corrections.single.item, 'Cotton Kurta KUR-BLU-L');
    expect(b.corrections.single.by, 'Asha');
    expect(b.purchaseOrdersReceived, 2);
    expect(b.newItems, 5);
  });

  test('day book without cost:view: no cost, profit or stock value', () {
    final b = dayBook(cost: false);
    expect(b.cost, isNull);
    expect(b.profit, isNull);
    expect(b.cameIn.value, isNull);
    expect(b.wentOut.value, isNull);
    // Everything else still reads.
    expect(b.revenue, 11530);
    expect(b.cameIn.units, 67);
  });

  test('day book: a day too old to check, and an empty shop', () {
    final b = DayBook.fromJson({
      'date': '2024-01-03',
      'inProgress': false,
      'quiet': true,
      'opening': {'units': '0', 'value': '0.00'},
      'closing': {'units': 0, 'value': 0},
      'measuredClosing': null,
      'balanced': null,
      'valueMatches': null,
      'valueGap': null,
      'stockIn': {'lines': [], 'totalUnits': 0, 'totalValue': 0},
      'stockOut': {'lines': [], 'totalUnits': 0, 'totalValue': 0},
      'money': {'taken': {}, 'paidBack': {}, 'cashInDrawer': 0},
    });
    expect(b.quiet, isTrue);
    expect(b.balanced, isNull);
    expect(b.valueMatches, isNull);
    expect(b.opening!.units, 0);
    expect(b.hasSales, isFalse);
    expect(b.taken, isEmpty);
    expect(b.dispatches, isEmpty);
  });
}
