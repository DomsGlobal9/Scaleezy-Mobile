import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/features/picking/data/picking_models.dart';
import 'package:scaleezy/features/picking/data/picking_repository.dart';

/// A repository whose server answers [reply] and remembers each request.
(PickingRepository, List<RequestOptions>) repoAnswering(Object? reply) {
  final seen = <RequestOptions>[];
  final dio = Dio()
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          seen.add(o);
          h.resolve(Response(requestOptions: o, statusCode: 200, data: reply));
        },
      ),
    );
  return (PickingRepository(ApiClient.withDio(dio)), seen);
}

void main() {
  test(
    'asks for one store\'s orders and reads them from data.orders',
    () async {
      final (repo, seen) = repoAnswering({
        'success': true,
        'data': {
          'location': {'id': 'L1', 'name': 'Main'},
          'orders': [
            {'id': 'so1', 'orderNumber': 'SO-1', 'pieces': 2},
          ],
        },
      });
      final orders = await repo.pickOrders('L1');

      expect(orders.single.orderNumber, 'SO-1');
      expect(seen.single.path, '/shelves/pick/orders');
      expect(seen.single.queryParameters, {'locationId': 'L1'});
    },
  );

  test('sends the chosen orders comma separated', () async {
    final (repo, seen) = repoAnswering({
      'success': true,
      'data': {'orders': [], 'stops': [], 'notShelved': [], 'short': []},
    });
    await repo.pickList('L1', ['so1', 'so2']);

    expect(seen.single.path, '/shelves/pick/list');
    expect(seen.single.queryParameters, {
      'locationId': 'L1',
      'orderIds': 'so1,so2',
    });
  });

  test(
    'reports not found and dispatches with the bodies the server checks',
    () async {
      final (repo, seen) = repoAnswering({
        'id': 'd1',
        'dispatchNumber': 'DSP-1',
      });
      await repo.reportNotFound(spotId: 'sp1', variantId: 'v1', missing: 2);
      await repo.dispatch('so1', [
        const DispatchLine(
          salesOrderItemId: 'i1',
          quantity: 2,
          fromSpots: {'sp1': 2},
        ),
      ]);

      expect(seen.map((o) => (o.method, o.path)), [
        ('POST', '/shelves/not-found'),
        ('POST', '/dispatches'),
      ]);
      expect(seen.first.data, {
        'spotId': 'sp1',
        'variantId': 'v1',
        'missing': 2,
      });
      expect(seen.last.data, {
        'salesOrderId': 'so1',
        'items': [
          {
            'salesOrderItemId': 'i1',
            'quantity': 2,
            'fromSpots': [
              {'spotId': 'sp1', 'quantity': 2},
            ],
          },
        ],
      });
    },
  );
}
