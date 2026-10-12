import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/features/stock_counts/data/stock_count_models.dart';

import 'stock_counts_fakes.dart';

void main() {
  test('a listed count reads its line count from _count', () {
    final c = StockCount.fromJson(countJson('c1', items: 120));
    expect(c.name, 'October 2026 Full Count');
    expect(c.status, 'IN_PROGRESS');
    expect(c.locationId, 'L1');
    expect(c.itemCount, 120);
    expect(c.isOpen, isTrue);
    expect(c.accuracy, isNull);
    expect(c.countedItems, isNull);
    expect(c.createdAt.toUtc(), DateTime.utc(2026, 10, 1, 9));
  });

  test('a completed count parses its Decimal accuracy and totals', () {
    final c = StockCount.fromJson({
      ...countJson('c1', status: 'COMPLETED', items: 40),
      // As completeCount answers: no _count, the persisted summary instead.
      '_count': null,
      'totalItems': 40,
      'matchedItems': 30,
      'adjustedItems': 4,
      'accuracy': '88.24',
      'completedAt': '2026-10-02T18:00:00.000Z',
      'completedBy': 'Asha',
    });
    expect(c.isOpen, isFalse);
    expect(c.itemCount, 40);
    expect(c.countedItems, 34);
    expect(c.adjustedItems, 4);
    expect(c.accuracy, 88.24);
    expect(c.completedBy, 'Asha');
    expect(c.completedAt, isNotNull);
  });

  test('a start answer (bare row) parses without counts', () {
    final c = StockCount.fromJson({
      ...countJson('c1'),
      '_count': null,
      'totalItems': null,
    });
    expect(c.itemCount, 0);
    expect(c.status, 'IN_PROGRESS');
  });

  test('a count detail sorts its lines and keeps 0 apart from not counted', () {
    final d = StockCountDetail.fromJson({
      ...countJson('c1'),
      'items': [
        lineJson('b', title: 'Silk Saree', expected: 10, counted: 0),
        lineJson('a', title: 'cotton Kurta', expected: 4, onHand: 2),
        lineJson('c', title: 'Silk Saree', expected: 2, counted: 3),
      ],
    });
    expect(d.count.itemCount, 3);
    expect(d.items.map((l) => l.id), ['a', 'b', 'c']);

    final kurta = d.items[0];
    expect(kurta.title, 'cotton Kurta');
    expect(kurta.counted, isNull);
    expect(kurta.difference, isNull);
    expect(kurta.onHand, 2);
    expect(kurta.barcode, '8901a');

    // Zero is a real count: nothing on the shelf.
    expect(d.items[1].counted, 0);
    expect(d.items[1].difference, -10);
    expect(d.items[2].difference, 1);
  });

  test(
    'a saved line answers without its product; a recount keeps the rest',
    () {
      final saved = savedLine('a', expected: 8, counted: 7);
      expect(saved.title, 'Product');
      expect(saved.onHand, 8);
      expect(saved.barcode, isNull);

      final before = StockCountItem.fromJson(
        lineJson('a', title: 'Kurta', expected: 10, onHand: 8),
      );
      final after = before.withCount(expected: 8, counted: 7);
      expect(after.title, 'Kurta');
      expect(after.difference, -1);
      expect(after.onHand, 8);
      final cleared = after.withCount(expected: 8, counted: null);
      expect(cleared.counted, isNull);
    },
  );

  test('a code matches barcode, SKU or variant code, ignoring case', () {
    final l = StockCountItem.fromJson(lineJson('x', barcode: 'ABC123'));
    expect(l.matchesCode('abc123'), isTrue);
    expect(l.matchesCode('sku-x'), isTrue);
    expect(l.matchesCode('VC-x'), isTrue);
    expect(l.matchesCode('SKU-y'), isFalse);

    final noBarcode = StockCountItem.fromJson({
      ...lineJson('y'),
      'barcode': null,
    });
    expect(noBarcode.barcode, isNull);
    expect(noBarcode.matchesCode('8901y'), isFalse);
  });
}
