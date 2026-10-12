import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/utils/json_parse.dart';
import 'package:scaleezy/features/customers/data/customer_models.dart';

// Shapes from inventory_backend: loyalty.service customerPoints and
// store-credit.service customerCredit, inside the routes' {success, data}.
void main() {
  group('CustomerPoints', () {
    test('reads a balance, its rupee value, lapse date and changes', () {
      final p = CustomerPoints.fromJson(
        asMap(
          dataOf({
            'success': true,
            'data': {
              'enabled': true,
              'points': 1250,
              'value': 625, // 50 paise a point
              'lapsesOn': '2027-10-10T09:15:00.000Z',
              'entries': [
                {
                  'id': 'le2',
                  'kind': 'USED',
                  'label': 'Used on a bill',
                  'points': -200,
                  'balance': 1250,
                  'note': null,
                  'orderId': 'o2',
                  'orderNumber': 'SO-2026-0042',
                  'returnId': null,
                  'at': '2026-10-10T09:15:00.000Z',
                },
                {
                  'id': 'le1',
                  'kind': 'ADJUSTED',
                  'label': 'Changed by hand',
                  'points': 1450,
                  'balance': 1450,
                  'note': 'Welcome gift',
                  'orderId': null,
                  'orderNumber': null,
                  'returnId': null,
                  'at': '2026-09-01T09:15:00.000Z',
                },
              ],
            },
          }),
        ),
      );

      expect(p.enabled, isTrue);
      expect(p.points, 1250);
      expect(p.value, 625);
      expect(p.lapsesOn, DateTime.utc(2027, 10, 10, 9, 15).toLocal());
      expect(p.worthShowing, isTrue);
      expect(p.entries.map((e) => e.label), [
        'Used on a bill',
        'Changed by hand',
      ]);
      expect(p.entries.first.change, -200);
      expect(p.entries.first.reference, 'SO-2026-0042');
      expect(p.entries.last.reference, isNull);
      expect(p.entries.last.note, 'Welcome gift');
    });

    test('loyalty off and never used: nothing worth showing', () {
      final p = CustomerPoints.fromJson({
        'enabled': false,
        'points': 0,
        'value': 0,
        'lapsesOn': null,
        'entries': [],
      });
      expect(p.worthShowing, isFalse);
      expect(p.lapsesOn, isNull);

      // Switched off later: what they hold is still shown.
      expect(
        CustomerPoints.fromJson({
          'enabled': false,
          'points': 40,
          'value': 40,
        }).worthShowing,
        isTrue,
      );
    });

    test('tolerates strings, a missing label and an empty body', () {
      final p = CustomerPoints.fromJson({
        'enabled': true,
        'points': '30',
        'value': '1.50',
        'entries': [
          {'id': 'x', 'kind': 'BIRTHDAY', 'points': '30'},
        ],
      });
      expect(p.points, 30);
      expect(p.value, 1.5);
      expect(p.entries.single.label, 'BIRTHDAY');
      expect(p.entries.single.change, 30);

      final empty = CustomerPoints.fromJson(const {});
      expect(empty.enabled, isFalse);
      expect(empty.worthShowing, isFalse);
    });
  });

  group('StoreCredit', () {
    test('reads the credit and changes, naming the return before the bill', () {
      final c = StoreCredit.fromJson({
        'credit': 349.5,
        'entries': [
          {
            'id': 'sc2',
            'kind': 'USED',
            'label': 'Used on a bill',
            'amount': -150,
            'balance': 349.5,
            'note': '₹150 off the bill',
            'orderId': 'o9',
            'orderNumber': 'SO-2026-0050',
            'returnId': null,
            'returnNumber': null,
            'at': '2026-10-11T10:00:00.000Z',
          },
          {
            'id': 'sc1',
            'kind': 'FROM_RETURN',
            'label': 'From a return',
            'amount': 499.5,
            'balance': 499.5,
            'note': null,
            'orderId': 'o7',
            'orderNumber': 'SO-2026-0040',
            'returnId': 'r1',
            'returnNumber': 'RET-0007',
            'at': '2026-10-01T10:00:00.000Z',
          },
        ],
      });

      expect(c.credit, 349.5);
      expect(c.worthShowing, isTrue);
      expect(c.entries.first.change, -150);
      expect(c.entries.first.reference, 'SO-2026-0050');
      expect(c.entries.last.change, 499.5);
      expect(c.entries.last.reference, 'RET-0007');
    });

    test('none held and no history: nothing worth showing', () {
      expect(
        StoreCredit.fromJson({'credit': 0, 'entries': []}).worthShowing,
        isFalse,
      );
      // Spent down to nothing still has a history to show.
      expect(
        StoreCredit.fromJson({
          'credit': '0.00',
          'entries': [
            {'id': 'a', 'label': 'Used on a bill', 'amount': '-99.00'},
          ],
        }).worthShowing,
        isTrue,
      );
    });
  });
}
