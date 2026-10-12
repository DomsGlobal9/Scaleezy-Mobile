import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/features/picking/presentation/view_models/pick_orders_view_model.dart';

import 'picking_fakes.dart';

void main() {
  test('lists the orders of the store it is given', () async {
    final repo = FakePickingRepository(orders: (_) async => [order('o1')]);
    final vm = PickOrdersViewModel(repo)..show(store('L2'));
    await pumpEventQueue();

    expect(vm.location?.id, 'L2');
    expect(vm.orders?.single.id, 'o1');
    expect(repo.calls, ['orders L2']);
  });

  test('before the shop knows its store there is nothing to load', () async {
    final repo = FakePickingRepository();
    final vm = PickOrdersViewModel(repo)..show(null);
    await pumpEventQueue();

    expect(vm.error, isNull);
    expect(vm.orders, isNull);
    expect(repo.calls, isEmpty);
  });

  test('another store starts afresh with nothing chosen', () async {
    final repo = FakePickingRepository(orders: (_) async => [order('o1')]);
    final vm = PickOrdersViewModel(repo)..show(store('L1'));
    await pumpEventQueue();
    vm.toggle('o1');

    vm.show(store('L1')); // the same store reloads and keeps the choice
    await pumpEventQueue();
    expect(vm.selected, ['o1']);

    vm.show(store('L2'));
    expect(vm.orders, isNull);
    expect(vm.selected, isEmpty);
    await pumpEventQueue();
    expect(repo.calls, ['orders L1', 'orders L1', 'orders L2']);
  });

  test('a failed load shows the server message', () async {
    final repo = FakePickingRepository(
      orders: (_) async =>
          throw const ApiException('Could not load the orders to pick.'),
    );
    final vm = PickOrdersViewModel(repo)..show(store('L1'));
    await pumpEventQueue();

    expect(vm.orders, isNull);
    expect(vm.error?.message, 'Could not load the orders to pick.');
  });

  test('chooses orders one by one, at most 30, or all at once', () async {
    final many = [for (var i = 0; i < 32; i++) order('o$i')];
    final vm = PickOrdersViewModel(
      FakePickingRepository(orders: (_) async => many),
    )..show(store('L1'));
    await pumpEventQueue();

    vm.toggle('o3');
    vm.toggle('o1');
    expect(vm.selected, ['o3', 'o1']);
    vm.toggle('o3');
    expect(vm.selected, ['o1']);

    vm.selectAllOrClear(); // some chosen: clears
    expect(vm.selected, isEmpty);
    vm.selectAllOrClear(); // none chosen: the oldest 30
    expect(vm.selected.length, PickOrdersViewModel.maxOrders);
    expect(vm.selected.first, 'o0');

    vm.toggle('o31'); // a 31st is refused
    expect(vm.isSelected('o31'), isFalse);
  });

  test('after sending out, the choice clears and the orders reload', () async {
    var orders = [order('o1'), order('o2')];
    final repo = FakePickingRepository(orders: (_) async => orders);
    final vm = PickOrdersViewModel(repo)..show(store('L1'));
    await pumpEventQueue();
    vm.toggle('o1');
    vm.toggle('o2');

    // o1 went out elsewhere: a reload drops it from the choice.
    orders = [order('o2')];
    await vm.load();
    expect(vm.selected, ['o2']);

    orders = [];
    vm.clearSelection();
    await pumpEventQueue();
    expect(vm.selected, isEmpty);
    expect(vm.orders, isEmpty);
    expect(repo.calls, ['orders L1', 'orders L1', 'orders L1']);
  });
}
