import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/features/dashboard/data/dashboard_models.dart';
import 'package:scaleezy/features/dashboard/presentation/view_models/home_view_model.dart';

import '../orders/orders_fakes.dart';
import '../products/products_fakes.dart' show variant;
import 'dashboard_fakes.dart';

void main() {
  final now = DateTime.now();
  final yesterday = DateTime(now.year, now.month, now.day - 1, 12);

  test('with every permission, all four calls go out together', () async {
    final pending = Completer<DashboardSummary>();
    final inventory = FakeHomeInventoryRepository(
      lowStock: () async => [variant('v1', colour: 'Red', quantity: 1)],
      movements: () async => [
        movement('m1', 5, now),
        movement('m2', -3, now),
        movement('m3', 2, yesterday),
      ],
    );
    final orders = FakeOrderRepository(
      answer: () async => [
        order('a', total: 500, pieces: 2),
        order('b', total: 300, status: 'CANCELLED'),
        order('c', total: 200, status: 'DRAFT', date: yesterday),
      ],
    );
    final vm = HomeViewModel(
      dashboard: FakeDashboardRepository(() => pending.future),
      inventory: inventory,
      orders: orders,
    );

    final loading = vm.load(canViewInventory: true, canViewOrders: true);
    // The optional calls do not wait for the summary.
    expect(inventory.calls, ['lowStock:6', 'transactions:200']);
    expect(orders.searches, [null]);
    pending.complete(summary());
    await loading;

    final d = vm.data!;
    expect(d.lowStock.map((v) => v.id), ['v1']);
    expect(d.movements, hasLength(3));
    expect(d.orders, hasLength(3));

    final flow = vm.lastSevenDays!;
    expect(flow, hasLength(7));
    expect((flow.last.inQty, flow.last.outQty), (5, 3));
    expect((flow[5].inQty, flow[5].outQty), (2, 0));
    expect((vm.flowIn, vm.flowOut), (7, 3));
    expect(vm.flowTruncated, isFalse);
    expect(vm.recentMovements, hasLength(3));

    expect(vm.todayOrders.map((o) => o.id), ['a']);
    expect(vm.todayTakings, 500);
    expect(vm.todayPieces, 2);
    expect(vm.drafts, 1);
  });

  test('without permissions only the summary is asked for', () async {
    final inventory = FakeHomeInventoryRepository();
    final orders = FakeOrderRepository();
    final vm = HomeViewModel(
      dashboard: FakeDashboardRepository(
        () async => summary(recent: [movementJson('r1', 4, now)]),
      ),
      inventory: inventory,
      orders: orders,
    );

    await vm.load(canViewInventory: false, canViewOrders: false);

    expect(inventory.calls, isEmpty);
    expect(orders.searches, isEmpty);
    expect(vm.data!.lowStock, isEmpty);
    expect(vm.data!.movements, isNull);
    expect(vm.data!.orders, isNull);
    expect(vm.lastSevenDays, isNull);
    // The summary's own few movements fill in.
    expect(vm.recentMovements.map((m) => m.id), ['r1']);
  });

  test('a failed optional section is skipped, not an error', () async {
    final vm = HomeViewModel(
      dashboard: FakeDashboardRepository(() async => summary()),
      inventory: FakeHomeInventoryRepository(
        lowStock: () async => [],
        movements: () async => throw const ApiException('No access.'),
      ),
      orders: FakeOrderRepository(answer: () async => []),
    );

    await vm.load(canViewInventory: true, canViewOrders: true);

    expect(vm.error, isNull);
    expect(vm.data!.movements, isNull);
    expect(vm.data!.orders, isEmpty);
  });

  test('a failed summary shows the server message', () async {
    final vm = HomeViewModel(
      dashboard: FakeDashboardRepository(
        () async => throw const ApiException('The server is busy.'),
      ),
      inventory: FakeHomeInventoryRepository(),
      orders: FakeOrderRepository(),
    );

    await vm.load(canViewInventory: false, canViewOrders: false);

    expect(vm.data, isNull);
    expect(vm.error, 'The server is busy.');
  });

  test('a full sample from this week marks the chart as partial', () async {
    final vm = HomeViewModel(
      dashboard: FakeDashboardRepository(() async => summary()),
      inventory: FakeHomeInventoryRepository(
        lowStock: () async => [],
        movements: () async => [
          for (var i = 0; i < HomeViewModel.movementSample; i++)
            movement('m$i', 1, now),
        ],
      ),
      orders: FakeOrderRepository(),
    );

    await vm.load(canViewInventory: true, canViewOrders: false);

    expect(vm.flowTruncated, isTrue);
    expect(vm.flowIn, HomeViewModel.movementSample);
  });

  test('a slow load for the previous store is dropped', () async {
    final slow = Completer<DashboardSummary>();
    var call = 0;
    final vm = HomeViewModel(
      dashboard: FakeDashboardRepository(
        () => ++call == 1 ? slow.future : Future.value(summary(totalUnits: 7)),
      ),
      inventory: FakeHomeInventoryRepository(),
      orders: FakeOrderRepository(),
    );

    final first = vm.load(canViewInventory: false, canViewOrders: false);
    await vm.load(canViewInventory: false, canViewOrders: false);
    slow.complete(summary(totalUnits: 999));
    await first;

    expect(vm.data?.summary.totalUnits, 7);
  });
}
