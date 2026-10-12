import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/features/purchase_orders/presentation/view_models/purchase_order_view_model.dart';
import 'package:scaleezy/features/purchase_orders/presentation/view_models/purchase_orders_view_model.dart';
import 'package:scaleezy/features/purchase_orders/presentation/view_models/receive_delivery_view_model.dart';

import 'purchase_orders_fakes.dart';

void main() {
  group('purchase orders list', () {
    final orders = [
      summary('a', status: 'SENT'),
      summary('b', status: 'PARTIALLY_RECEIVED'),
      summary('c', status: 'DRAFT'),
      summary('d', status: 'RECEIVED'),
    ];

    test('loads and filters, starting with what is to receive', () async {
      final vm = PurchaseOrdersViewModel(
        FakePurchaseOrderRepository(list: () async => orders),
      );
      expect(vm.all, isNull);
      await vm.load();

      expect(vm.filter, 'OPEN');
      expect(vm.visible.map((p) => p.id), ['a', 'b']);
      expect(vm.count('OPEN'), 2);
      expect(vm.count('ALL'), 4);
      expect(vm.count('CANCELLED'), 0);

      vm.selectFilter('DRAFT');
      expect(vm.visible.map((p) => p.id), ['c']);
    });

    test('a failed load shows the server message', () async {
      final vm = PurchaseOrdersViewModel(
        FakePurchaseOrderRepository(
          list: () async => throw const ApiException('No access.'),
        ),
      );
      await vm.load();
      expect(vm.error, 'No access.');
      expect(vm.all, isNull);
    });
  });

  group('one purchase order', () {
    test('loads its lines and totals the pieces', () async {
      final repo = FakePurchaseOrderRepository(one: () async => detail());
      final vm = PurchaseOrderViewModel('po1', repo);
      await vm.load();

      expect(repo.loaded, ['po1']);
      expect((vm.ordered, vm.received), (15, 6));
      expect(vm.changed, isFalse);
    });

    test('a received delivery reloads and marks it changed', () async {
      final repo = FakePurchaseOrderRepository(one: () async => detail());
      final vm = PurchaseOrderViewModel('po1', repo);
      await vm.load();

      await vm.deliveryReceived();
      expect(vm.changed, isTrue);
      expect(repo.loaded, ['po1', 'po1']);
    });

    test('a failed load shows the server message', () async {
      final vm = PurchaseOrderViewModel(
        'po1',
        FakePurchaseOrderRepository(
          one: () async => throw const ApiException('Not found.'),
        ),
      );
      await vm.load();
      expect(vm.error, 'Not found.');
      expect(vm.po, isNull);
    });
  });

  group('receive delivery', () {
    test('only lines still to come, counted by stepper, scan and all', () {
      final vm = ReceiveDeliveryViewModel(
        detail(),
        FakePurchaseOrderRepository(),
      );
      expect(vm.lines.map((l) => l.id), ['i1', 'i2']);
      expect(vm.outstanding, 9);
      expect(vm.total, 0);

      vm.setQty('i1', 2);
      expect(vm.scan('BC-i2'), '+1  Saree i2  (1/3)');
      expect(vm.scan('SKU-i2'), '+1  Saree i2  (2/3)');
      expect(vm.scan('nope'), 'Not on this order: nope');
      expect((vm.total, vm.countedLines), (4, 2));

      vm.allArrived();
      expect(vm.total, 9);
      expect(vm.scan('BC-i2'), 'All 3 of Saree i2 already counted');
      expect(vm.qty('i2'), 3);
    });

    test('validate asks for a count, then a name', () {
      final vm = ReceiveDeliveryViewModel(
        detail(),
        FakePurchaseOrderRepository(),
      );
      expect(vm.validate('Asha'), 'Count at least one piece first.');
      vm.setQty('i1', 1);
      expect(
        vm.validate(' A '),
        'Enter the name of the person who received the goods.',
      );
      expect(vm.error, isNotNull);
      expect(vm.validate('Asha'), isNull);
    });

    test('a failed receive returns the message, and the retry reuses the '
        'request key', () async {
      var fail = true;
      final repo = FakePurchaseOrderRepository(
        receive: () async {
          if (fail) throw const ApiException('Timed out.');
        },
      );
      final vm = ReceiveDeliveryViewModel(detail(), repo);
      vm.setQty('i1', 2);

      expect(
        await vm.receive(receivedBy: 'Asha', reference: 'INV-1'),
        'Timed out.',
      );
      expect(vm.busy, isFalse);

      fail = false;
      expect(await vm.receive(receivedBy: 'Asha', reference: 'INV-1'), isNull);
      expect(vm.busy, isTrue); // the screen closes

      expect(repo.receipts, hasLength(2));
      expect(repo.receipts.first, {
        'id': 'po1',
        'quantities': {'i1': 2, 'i2': 0},
        'receivedByName': 'Asha',
        'supplierReference': 'INV-1',
        'requestKey': vm.requestKey,
      });
      expect(
        repo.receipts.last['requestKey'],
        repo.receipts.first['requestKey'],
      );
    });
  });
}
