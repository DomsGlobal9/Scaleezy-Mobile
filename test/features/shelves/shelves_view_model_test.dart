import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/features/shelves/data/shelf_models.dart';
import 'package:scaleezy/features/shelves/presentation/view_models/shelves_view_model.dart';

import 'shelves_fakes.dart';

void main() {
  test(
    'opens on the selected store, else the first store that is not online',
    () async {
      final repo = FakeShelfRepository(
        tree: (id) async => treeOf(id, [shelf('s1')]),
      );
      final online = store('web', type: 'ONLINE');

      final picked = ShelvesViewModel(repo);
      picked.start(store('L2'), [online, store('L1'), store('L2')]);
      await pumpEventQueue();
      expect(picked.location?.id, 'L2');

      final first = ShelvesViewModel(repo);
      first.start(null, [online, store('L1')]);
      await pumpEventQueue();
      expect(first.location?.id, 'L1');
      expect(first.tree?.locationId, 'L1');
      expect(first.error, isNull);

      final onlineOnly = ShelvesViewModel(repo);
      onlineOnly.start(null, [online]);
      expect(onlineOnly.location?.id, 'web');

      expect(repo.calls, ['tree L2', 'tree L1', 'tree web']);
    },
  );

  test('with no store there is nothing to load', () async {
    final repo = FakeShelfRepository();
    final vm = ShelvesViewModel(repo)..start(null, const []);
    await vm.load();

    expect(vm.location, isNull);
    expect(
      vm.error,
      'No store is set up yet, so there are no shelves to show.',
    );
    expect(repo.calls, isEmpty);
  });

  test(
    'a failed load shows the server message and keeps the last tree',
    () async {
      var fail = false;
      final repo = FakeShelfRepository(
        tree: (id) async => fail
            ? throw const ApiException('The server is busy.')
            : treeOf(id, []),
      );
      final vm = ShelvesViewModel(repo)..start(store('L1'), const []);
      await pumpEventQueue();

      fail = true;
      await vm.load();
      expect(vm.error, 'The server is busy.');
      expect(vm.tree, isNotNull);
    },
  );

  test('picking another store clears the tree and loads that store', () async {
    final repo = FakeShelfRepository(tree: (id) async => treeOf(id, []));
    final vm = ShelvesViewModel(repo)..start(store('L1'), const []);
    await pumpEventQueue();

    vm.pickLocation(store('L1')); // already showing
    expect(repo.calls, ['tree L1']);

    vm.pickLocation(store('L2'));
    expect(vm.tree, isNull);
    await pumpEventQueue();
    expect(vm.tree?.locationId, 'L2');
    expect(repo.calls, ['tree L1', 'tree L2']);
  });

  test('scanning a label looks it up in this store', () async {
    final repo = FakeShelfRepository(
      tree: (id) async => treeOf(id, []),
      scan: (code) async => code == 'R1-S1'
          ? spotContents('s1')
          : throw const ApiException('No shelf has that label.'),
    );
    final vm = ShelvesViewModel(repo)..start(store('L1'), const []);

    expect(await vm.scanLabel('R1-S1'), isNull);
    expect(vm.scanned?.spotId, 's1');

    expect(await vm.scanLabel('nope'), 'No shelf has that label.');
    expect(repo.calls, ['tree L1', 'scan R1-S1 @L1', 'scan nope @L1']);
  });

  test('a tree for the previous store that arrives late is dropped', () async {
    final slow = Completer<ShelfTree>();
    final repo = FakeShelfRepository(
      tree: (id) => id == 'L1' ? slow.future : Future.value(treeOf(id, [])),
    );
    final vm = ShelvesViewModel(repo)
      ..start(store('L1'), [store('L1'), store('L2')]);
    vm.pickLocation(store('L2'));
    await pumpEventQueue();
    slow.complete(treeOf('L1', []));
    await pumpEventQueue();

    expect(vm.tree?.locationId, 'L2');
  });
}
