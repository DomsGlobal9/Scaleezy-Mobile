import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/features/shelves/presentation/view_models/spot_view_model.dart';

import 'shelves_fakes.dart';

void main() {
  final saree = item('v1', quantity: 4);

  test('loads the shelf, and a failure shows the server message', () async {
    var fail = false;
    final repo = FakeShelfRepository(
      spotAnswer: (id) async => fail
          ? throw const ApiException('Shelf not found.')
          : spotContents(id, items: [saree]),
    );
    final vm = SpotViewModel('s1', repo);

    await vm.load();
    expect(vm.spot?.items.single.variantId, 'v1');
    expect(vm.error, isNull);

    fail = true;
    await vm.load();
    expect(vm.error, 'Shelf not found.');
    expect(vm.spot, isNotNull);
  });

  test('moving sends the shelf, keeps the warning and reloads', () async {
    final repo = FakeShelfRepository(
      spotAnswer: (id) async => spotContents(id, items: [saree]),
      write: () async => 'That shelf is now over its capacity.',
    );
    final vm = SpotViewModel('s1', repo);
    await vm.load();

    expect(await vm.move(saree, shelf('s2'), 3), isNull);
    expect(vm.warning, 'That shelf is now over its capacity.');
    expect(repo.writes.single, {
      'locationId': 'L1',
      'variantId': 'v1',
      'fromSpotId': 's1',
      'toSpotId': 's2',
      'quantity': 3,
    });
    expect(repo.calls, ['spot s1', 'move', 'spot s1']);
  });

  test('moving off the shelf sends no target', () async {
    final repo = FakeShelfRepository(
      spotAnswer: (id) async => spotContents(id, items: [saree]),
      write: () async => null,
    );
    final vm = SpotViewModel('s1', repo);
    await vm.load();

    expect(await vm.move(saree, null, 1), isNull);
    expect(vm.warning, isNull);
    expect(repo.writes.single['toSpotId'], isNull);
  });

  test(
    'a failed move returns the server message and does not reload',
    () async {
      final repo = FakeShelfRepository(
        spotAnswer: (id) async => spotContents(id, items: [saree]),
        write: () async =>
            throw const ApiException('Only 4 are on this shelf.'),
      );
      final vm = SpotViewModel('s1', repo);
      await vm.load();

      expect(await vm.move(saree, shelf('s2'), 9), 'Only 4 are on this shelf.');
      expect(repo.calls, ['spot s1', 'move']);
    },
  );
}
