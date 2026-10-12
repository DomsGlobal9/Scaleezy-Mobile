import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/features/shelves/presentation/view_models/move_sheet_view_model.dart';

import 'shelves_fakes.dart';

void main() {
  final rack = shelf(
    'r1',
    children: [
      shelf('s1', name: 'Silk top'),
      shelf('s2', name: 'Cotton'),
      shelf('s3', active: false),
    ],
  );

  test(
    'lists active shelves that hold pieces, except the current one',
    () async {
      final repo = FakeShelfRepository(tree: (id) async => treeOf(id, [rack]));
      final vm = MoveSheetViewModel(
        locationId: 'L1',
        maxQty: 4,
        excludeSpotId: 's2',
        repo: repo,
      );
      expect(vm.loadingSpots, isTrue);
      expect(vm.qty, 4);
      expect(vm.ready, isFalse);

      await vm.load();
      expect(vm.loadingSpots, isFalse);
      expect(vm.spots.map((s) => s.id), ['s1']);
      expect(repo.calls, ['tree L1']);
    },
  );

  test('a failed list leaves nothing to pick', () async {
    final repo = FakeShelfRepository(
      tree: (_) async => throw const ApiException('The server is busy.'),
    );
    final vm = MoveSheetViewModel(locationId: 'L1', maxQty: 1, repo: repo);

    await vm.load();
    expect(vm.loadingSpots, isFalse);
    expect(vm.spots, isEmpty);
  });

  test('the filter narrows by address or name', () async {
    final repo = FakeShelfRepository(tree: (id) async => treeOf(id, [rack]));
    final vm = MoveSheetViewModel(locationId: 'L1', maxQty: 1, repo: repo);
    await vm.load();

    vm.setFilter('silk');
    expect(vm.spots.map((s) => s.id), ['s1']);
    vm.setFilter('S2');
    expect(vm.spots.map((s) => s.id), ['s2']);
  });

  test('choosing a shelf or off the shelf sets what the sheet hands back', () {
    final vm = MoveSheetViewModel(
      locationId: 'L1',
      maxQty: 5,
      repo: FakeShelfRepository(),
    );

    vm.choose(shelf('s1'));
    vm.setQty(2);
    expect(vm.ready, isTrue);
    expect(vm.result.$1?.id, 's1');
    expect(vm.result.$2, 2);

    vm.takeOffShelf();
    expect(vm.to, isNull);
    expect(vm.ready, isTrue);
    expect(vm.result.$1, isNull);
  });

  test(
    'putting away needs a shelf; a fixed target is chosen already',
    () async {
      final repo = FakeShelfRepository();
      final needsShelf = MoveSheetViewModel(
        locationId: 'L1',
        maxQty: 3,
        requireTarget: true,
        repo: repo,
      )..takeOffShelf();
      expect(needsShelf.ready, isFalse);

      final fixed = MoveSheetViewModel(
        locationId: 'L1',
        maxQty: 3,
        fixedTarget: spotContents('s9'),
        requireTarget: true,
        repo: repo,
      );
      await fixed.load();
      expect(fixed.to?.id, 's9');
      expect(fixed.ready, isTrue);
      expect(repo.calls, isEmpty); // nothing to list
    },
  );

  test('scanning a label picks that shelf', () async {
    final repo = FakeShelfRepository(
      scan: (code) async => switch (code) {
        'S1' => spotContents('s1'),
        'R1' => spotContents('r1', holdsStock: false),
        _ => throw const ApiException('No shelf has that label.'),
      },
    );
    final vm = MoveSheetViewModel(locationId: 'L1', maxQty: 1, repo: repo)
      ..takeOffShelf();

    expect(await vm.scanTarget('S1'), isNull);
    expect(vm.to?.id, 's1');
    expect(vm.offShelf, isFalse);

    expect(
      await vm.scanTarget('R1'),
      'R1 holds other shelves. Scan one of those.',
    );
    expect(await vm.scanTarget('??'), 'No shelf has that label.');
    expect(vm.to?.id, 's1');
    expect(repo.calls, ['scan S1 @L1', 'scan R1 @L1', 'scan ?? @L1']);
  });
}
