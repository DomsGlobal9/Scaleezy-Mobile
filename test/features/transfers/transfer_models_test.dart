import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/features/transfers/data/transfer_models.dart';
import 'package:scaleezy/features/transfers/data/transfer_repository.dart';

import '../../support/fake_api.dart';
import '../../support/fixtures.dart';

void main() {
  group('StoreStock', () {
    test('reads a row with cost fields, which it ignores', () {
      final s = StoreStock.fromJson({
        ...stockRow('v1', title: 'Kanchipuram Silk Saree', quantity: 7),
        'averageCost': 1200,
        'inventoryValue': 8400,
      });
      expect(
        (s.variantId, s.title, s.sku, s.quantity),
        ('v1', 'Kanchipuram Silk Saree', 'SKU-v1', 7),
      );
    });

    test('tolerates a row without cost:view, a string count and no title', () {
      final s = StoreStock.fromJson({
        'variantId': 'v2',
        'sku': 'SAR-RED-M',
        'productTitle': '',
        'quantity': '3',
      });
      expect((s.title, s.quantity), ('SAR-RED-M', 3));
      expect(StoreStock.fromJson(const {}).quantity, 0);
    });
  });

  group('TransferRepository', () {
    test(
      'asks for stock at one store and reads {success, data: {items}}',
      () async {
        final api = FakeApi()
          ..get(
            '/inventory/variants',
            itemsPage([stockRow('v1', quantity: 4)]),
          );
        final repo = TransferRepository(api.client);
        final rows = await repo.stockAt('L1', search: ' saree ');
        expect(rows.single.quantity, 4);
        expect(api.requests.single.path, '/inventory/variants');
        expect(api.requests.single.query, {
          'locationId': 'L1',
          'search': 'saree',
          'limit': '20',
        });
      },
    );

    test('sends the move in the backend field names', () async {
      final api = FakeApi()
        ..post('/inventory-transfers', transferJson(items: 2));
      final repo = TransferRepository(api.client);
      await repo.transfer(
        fromId: 'L1',
        toId: 'L2',
        quantities: {'v1': 3, 'v2': 1},
        notes: '  For the window  ',
      );
      await repo.transfer(
        fromId: 'L1',
        toId: 'L2',
        quantities: {'v1': 1},
        notes: ' ',
      );
      expect(api.log, [
        'POST /inventory-transfers',
        'POST /inventory-transfers',
      ]);
      expect(api.requests.first.body, {
        'originLocationId': 'L1',
        'destinationLocationId': 'L2',
        'items': [
          {'variantId': 'v1', 'quantity': 3},
          {'variantId': 'v2', 'quantity': 1},
        ],
        'notes': 'For the window',
      });
      expect((api.requests.last.body as Map).containsKey('notes'), isFalse);
    });
  });
}
