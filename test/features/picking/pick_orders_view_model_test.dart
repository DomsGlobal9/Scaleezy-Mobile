import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/features/picking/presentation/view_models/pick_orders_view_model.dart';

import 'picking_fakes.dart';

void main() {
  test(
    'opens on the selected store, else the first store that is not online',
    () async {
      final repo = FakePickingRepository(orders: (_) async => [order('o1')]);
      final online = store('web', type: 'ONLINE');

      final picked = PickOrdersViewModel(repo)
        ..start(store('L2'), [online, store('L1'), store('L2')]);
      await pumpEventQueue();
      expect(picked.location?.id, 'L2');
      expect(picked.orders?.single.id, 'o1');

      final first = PickOrdersViewModel(repo)
        ..start(null, [online, store('L1')]);
      await pumpEventQueue();
      expect(first.location?.id, 'L1');

      expect(repo.calls, ['orders L2', 'orders L1']);
    },
  );

  test('with no store there is nothing to load', () async {
    final repo = FakePickingRepository();
    final vm = PickOrdersViewModel(repo)..start(null, const []);
    await pumpEventQueue();

    expect(vm.error, 'No store is set up yet, so there are no orders to pick.');
    expect(repo.calls, isEmpty);
  });

  test('a failed load shows the server message', () async {
    final repo = FakePickingRepository(
      orders: (_) async =>
          throw const ApiException('Could not load the orders to pick.'),
    );
    final vm = PickOrdersViewModel(repo)..start(store('L1'), const []);
    await pumpEventQueue();

    expect(vm.orders, isNull);
    expect(vm.error, 'Could not load the orders to pick.');
  });

  test('chooses orders one by one, at most 30, or all at once', () async {
    final many = [for (var i = 0; i < 32; i++) order('o$i')];
    final vm = PickOrdersViewModel(
      FakePickingRepository(orders: (_) async => many),
    )..start(store('L1'), const []);
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
    final vm = PickOrdersViewModel(repo)..start(store('L1'), const []);
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
