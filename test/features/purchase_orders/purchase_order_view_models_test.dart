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

    test('loads every status, filters as the website, and searches', () async {
      final vm = PurchaseOrdersViewModel(
        FakePurchaseOrderRepository(list: () async => orders),
      );
      expect(vm.all, isNull);
      await vm.load();

      expect(vm.filter, '');
      expect(vm.visible.map((p) => p.id), ['a', 'b', 'c', 'd']);
      expect(vm.count('open'), 2);
      expect(vm.count(''), 4);
      expect(vm.count('cancelled'), 0);

      vm.selectFilter('draft');
      expect(vm.visible.map((p) => p.id), ['c']);
      vm.selectFilter('partly_received');
      expect(vm.visible.map((p) => p.id), ['b']);
      vm.selectFilter('sent');
      expect(vm.visible.map((p) => p.id), ['a']);
      vm.selectFilter('nonsense'); // an old link: every status
      expect(vm.filter, '');

      vm.search('po-d');
      expect(vm.visible.map((p) => p.id), ['d']);
      vm.search('WEAVERS');
      expect(vm.visible, hasLength(4));
      vm.search('loom');
      expect(vm.visible, isEmpty);
    });

    test('a failed load shows the server message', () async {
      final vm = PurchaseOrdersViewModel(
        FakePurchaseOrderRepository(
          list: () async =>
              throw const ApiException('No access.', statusCode: 403),
        ),
      );
      await vm.load();
      expect(vm.error, 'No access.');
      expect(vm.failure!.isForbidden, isTrue);
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
          return (receiptNumber: 'GRN-0004', duplicate: false);
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
      expect(
        await vm.receive(
          receivedBy: 'Asha',
          reference: 'INV-1',
          locationId: 'store-2',
        ),
        isNull,
      );
      expect(vm.busy, isTrue); // the screen closes
      expect(vm.done, 'Received — GRN-0004');
      expect(repo.receipts.last['locationId'], 'store-2');

      expect(repo.receipts, hasLength(2));
      expect(repo.receipts.first, {
        'id': 'po1',
        'quantities': {'i1': 2, 'i2': 0},
        'receivedByName': 'Asha',
        'locationId': null,
        'supplierReference': 'INV-1',
        'requestKey': vm.requestKey,
      });
      expect(
        repo.receipts.last['requestKey'],
        repo.receipts.first['requestKey'],
      );
    });

    test('a retried receive the server already had says so', () async {
      final vm = ReceiveDeliveryViewModel(
        detail(),
        FakePurchaseOrderRepository(
          receive: () async => (receiptNumber: 'GRN-0004', duplicate: true),
        ),
      );
      vm.setQty('i1', 1);
      await vm.receive(receivedBy: 'Asha', reference: '');
      expect(vm.done, 'Already received — GRN-0004');
    });

    test('without a receipt number it still says it worked', () async {
      final vm = ReceiveDeliveryViewModel(
        detail(),
        FakePurchaseOrderRepository(
          receive: () async => (receiptNumber: null, duplicate: false),
        ),
      );
      vm.setQty('i1', 1);
      await vm.receive(receivedBy: 'Asha', reference: '');
      expect(vm.done, 'Goods received successfully');
    });

    test('asks only when the app store is not the order\'s active store', () {
      ReceiveDeliveryViewModel vmFor(Map<String, Object?>? location) =>
          ReceiveDeliveryViewModel(
            detail(location: location),
            FakePurchaseOrderRepository(),
          );
      final forMain = vmFor({'id': 'main', 'name': 'Main', 'active': true});
      expect(forMain.intoOtherStore('main'), isFalse);
      expect(forMain.intoOtherStore('branch'), isTrue);
      expect(forMain.intoOtherStore(null), isFalse); // store not known yet
      // The order's store is switched off, or none was chosen: nothing to ask.
      expect(
        vmFor({
          'id': 'main',
          'name': 'Main',
          'active': false,
        }).intoOtherStore('branch'),
        isFalse,
      );
      expect(vmFor(null).intoOtherStore('branch'), isFalse);
    });
  });
}
