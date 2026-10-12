import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/features/picking/data/picking_models.dart';
import 'package:scaleezy/features/picking/data/picking_repository.dart';

import '../../support/fake_api.dart';
import '../../support/fixtures.dart';

/// A repository whose server answers [reply] to everything, and the server.
(PickingRepository, FakeApi) repoAnswering(Object? reply) {
  final api = FakeApi(fallback: reply);
  return (PickingRepository(api.client), api);
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
      expect(seen.log, ['GET /shelves/pick/orders?locationId=L1']);
    },
  );

  test('sends the chosen orders comma separated', () async {
    final (repo, seen) = repoAnswering({
      'success': true,
      'data': {'orders': [], 'stops': [], 'notShelved': [], 'short': []},
    });
    await repo.pickList('L1', ['so1', 'so2']);

    expect(seen.requests.single.path, '/shelves/pick/list');
    expect(seen.requests.single.query, {
      'locationId': 'L1',
      'orderIds': 'so1,so2',
    });
  });

  test(
    'reports not found and dispatches with the bodies the server checks',
    () async {
      final (repo, seen) = repoAnswering(dispatchJson());
      await repo.reportNotFound(spotId: 'sp1', variantId: 'v1', missing: 2);
      await repo.dispatch('so1', [
        const DispatchLine(
          salesOrderItemId: 'i1',
          quantity: 2,
          fromSpots: {'sp1': 2},
        ),
      ]);

      expect(seen.log, ['POST /shelves/not-found', 'POST /dispatches']);
      expect(seen.requests.first.body, {
        'spotId': 'sp1',
        'variantId': 'v1',
        'missing': 2,
      });
      expect(seen.requests.last.body, {
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
