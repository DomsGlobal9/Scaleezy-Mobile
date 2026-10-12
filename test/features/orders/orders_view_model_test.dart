import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/features/orders/data/order_models.dart';
import 'package:scaleezy/features/orders/presentation/view_models/order_details_view_model.dart';
import 'package:scaleezy/features/orders/presentation/view_models/orders_view_model.dart';

import 'orders_fakes.dart';

void main() {
  final now = DateTime.now();
  final yesterday = DateTime(now.year, now.month, now.day - 1, 12);

  test('load, then status and counter filters work on what loaded', () async {
    final repo = FakeOrderRepository(
      answer: () async => [
        order('a', total: 100, atCounter: true),
        order('b', status: 'CANCELLED', total: 50),
        order('c', status: 'DRAFT', total: 30, date: yesterday),
      ],
    );
    final vm = OrdersViewModel(repo);

    await vm.load();
    expect(repo.searches, ['']);
    expect(vm.shown.map((o) => o.id), ['a', 'b', 'c']);
    expect(vm.value, 130); // cancelled left out
    expect(vm.countFor('ALL'), 3);
    expect(vm.countFor('DRAFT'), 1);
    // A (label, day total) header before each day.
    expect(vm.rows, [
      ('Today', 100.0),
      vm.shown[0],
      vm.shown[1],
      ('Yesterday', 30.0),
      vm.shown[2],
    ]);

    vm.selectStatus('DRAFT');
    expect(vm.shown.map((o) => o.id), ['c']);

    vm.selectStatus('ALL');
    vm.setCounterOnly(true);
    expect(vm.shown.map((o) => o.id), ['a']);
    expect(vm.countFor('DRAFT'), 0);
  });

  test('typing searches once, trimmed, after the pause', () async {
    final repo = FakeOrderRepository(answer: () async => []);
    final vm = OrdersViewModel(repo);

    vm.search('si');
    vm.search(' silk ');
    expect(vm.query, ' silk ');
    expect(repo.searches, isEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 500));

    expect(repo.searches, ['silk']);
    vm.dispose();
  });

  test('an answer that arrives after a newer load is dropped', () async {
    final slow = Completer<List<OrderItemSummary>>();
    var call = 0;
    final repo = FakeOrderRepository(
      answer: () => ++call == 1 ? slow.future : Future.value([order('new')]),
    );
    final vm = OrdersViewModel(repo);

    final first = vm.load();
    await vm.load();
    slow.complete([order('old')]);
    await first;

    expect(vm.orders!.map((o) => o.id), ['new']);
  });

  test('a failed load shows the server message', () async {
    final vm = OrdersViewModel(
      FakeOrderRepository(
        answer: () async => throw const ApiException('The server is busy.'),
      ),
    );

    await vm.load();

    expect(vm.orders, isNull);
    expect(vm.error, 'The server is busy.');
  });

  test('order details loads one order, or says why not', () async {
    final ok = OrderDetailsViewModel(
      'o1',
      FakeOrderRepository(detail: (id) async => orderDetail(id)),
    );
    expect(ok.detail, isNull);
    await ok.load();
    expect(ok.detail!.summary.orderNumber, 'SO-o1');
    expect(ok.error, isNull);

    final failed = OrderDetailsViewModel(
      'o1',
      FakeOrderRepository(
        detail: (_) async => throw const ApiException('Order not found.'),
      ),
    );
    await failed.load();
    expect(failed.detail, isNull);
    expect(failed.error, 'Order not found.');
  });
}
