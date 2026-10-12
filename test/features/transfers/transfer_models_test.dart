import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/features/transfers/data/transfer_models.dart';
import 'package:scaleezy/features/transfers/data/transfer_repository.dart';

import 'transfers_fakes.dart';

/// A client whose every request is recorded and answered with [answer].
ApiClient answering(Object? answer, List<RequestOptions> seen) =>
    ApiClient.withDio(
      Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (o, h) {
              seen.add(o);
              h.resolve(
                Response(requestOptions: o, statusCode: 200, data: answer),
              );
            },
          ),
        ),
    );

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
        final seen = <RequestOptions>[];
        final repo = TransferRepository(
          answering({
            'success': true,
            'data': {
              'items': [stockRow('v1', quantity: 4)],
              'pagination': {'total': 1, 'page': 1, 'limit': 20, 'pages': 1},
            },
          }, seen),
        );
        final rows = await repo.stockAt('L1', search: ' saree ');
        expect(rows.single.quantity, 4);
        expect(seen.single.path, '/inventory/variants');
        expect(seen.single.queryParameters, {
          'locationId': 'L1',
          'search': 'saree',
          'limit': 20,
        });
      },
    );

    test('sends the move in the backend field names', () async {
      final seen = <RequestOptions>[];
      final repo = TransferRepository(
        answering({'success': true, 'transferredItems': 2}, seen),
      );
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
      expect(seen.first.method, 'POST');
      expect(seen.first.path, '/inventory-transfers');
      expect(seen.first.data, {
        'originLocationId': 'L1',
        'destinationLocationId': 'L2',
        'items': [
          {'variantId': 'v1', 'quantity': 3},
          {'variantId': 'v2', 'quantity': 1},
        ],
        'notes': 'For the window',
      });
      expect((seen.last.data as Map).containsKey('notes'), isFalse);
    });
  });
}
