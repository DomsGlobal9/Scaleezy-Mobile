import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/features/shelves/data/shelf_models.dart';
import 'package:scaleezy/features/shelves/presentation/view_models/shelves_view_model.dart';

import 'shelves_fakes.dart';

void main() {
  test('shows the store it is given (the app\'s selected store)', () async {
    final repo = FakeShelfRepository(
      tree: (id) async => treeOf(id, [shelf('s1')]),
    );
    final vm = ShelvesViewModel(repo)..show(store('L2'));
    await pumpEventQueue();

    expect(vm.location?.id, 'L2');
    expect(vm.tree?.locationId, 'L2');
    expect(vm.error, isNull);
    expect(repo.calls, ['tree L2']);
  });

  test('before the shop knows its store there is nothing to load', () async {
    final repo = FakeShelfRepository();
    final vm = ShelvesViewModel(repo)..show(null);
    await pumpEventQueue();

    expect(vm.location, isNull);
    expect(vm.error, isNull);
    expect(repo.calls, isEmpty);
  });

  test('a failed load keeps the server error and the last tree', () async {
    var fail = false;
    final repo = FakeShelfRepository(
      tree: (id) async => fail
          ? throw const ApiException('The server is busy.')
          : treeOf(id, []),
    );
    final vm = ShelvesViewModel(repo)..show(store('L1'));
    await pumpEventQueue();

    fail = true;
    await vm.load();
    expect(vm.error?.message, 'The server is busy.');
    expect(vm.tree, isNotNull);
  });

  test('another store clears the tree and loads that store', () async {
    final repo = FakeShelfRepository(tree: (id) async => treeOf(id, []));
    final vm = ShelvesViewModel(repo)..show(store('L1'));
    await pumpEventQueue();

    // The same store again (e.g. the shop reloaded) keeps the tree while it refreshes.
    vm.show(store('L1'));
    expect(vm.tree, isNotNull);

    vm.show(store('L2'));
    expect(vm.tree, isNull);
    await pumpEventQueue();
    expect(vm.tree?.locationId, 'L2');
    expect(repo.calls, ['tree L1', 'tree L1', 'tree L2']);
  });

  test('scanning a label looks it up in this store', () async {
    final repo = FakeShelfRepository(
      tree: (id) async => treeOf(id, []),
      scan: (code) async => code == 'R1-S1'
          ? spotContents('s1')
          : throw const ApiException('No shelf has that label.'),
    );
    final vm = ShelvesViewModel(repo)..show(store('L1'));

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
    final vm = ShelvesViewModel(repo)..show(store('L1'));
    vm.show(store('L2'));
    await pumpEventQueue();
    slow.complete(treeOf('L1', []));
    await pumpEventQueue();

    expect(vm.tree?.locationId, 'L2');
  });
}
