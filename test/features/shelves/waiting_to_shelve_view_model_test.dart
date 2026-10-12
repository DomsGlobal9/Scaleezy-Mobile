import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/features/shelves/data/shelf_models.dart';
import 'package:scaleezy/features/shelves/presentation/view_models/waiting_to_shelve_view_model.dart';

import 'shelves_fakes.dart';

void main() {
  final kurta = NotShelvedItem(item: item('v1'), total: 5, notShelved: 3);
  final saree = NotShelvedItem(item: item('v2'), total: 2, notShelved: 2);

  test('loads what is waiting and counts the pieces', () async {
    var fail = false;
    final repo = FakeShelfRepository(
      waiting: () async => fail
          ? throw const ApiException('The server is busy.')
          : [kurta, saree],
    );
    final vm = WaitingToShelveViewModel('L1', repo);
    expect(vm.waiting, 0);

    await vm.load();
    expect(vm.items, hasLength(2));
    expect(vm.waiting, 5);

    fail = true;
    await vm.load();
    expect(vm.error, 'The server is busy.');
    expect(repo.calls, ['waiting L1', 'waiting L1']);
  });

  test('putting away sends the shelf, keeps the warning and reloads', () async {
    final repo = FakeShelfRepository(
      waiting: () async => [kurta],
      write: () async => null,
    );
    final vm = WaitingToShelveViewModel('L1', repo);
    await vm.load();

    expect(await vm.putAway(kurta, shelf('s1'), 2), isNull);
    expect(vm.warning, isNull);
    expect(repo.writes.single, {
      'locationId': 'L1',
      'variantId': 'v1',
      'spotId': 's1',
      'quantity': 2,
    });
    expect(repo.calls, ['waiting L1', 'putAway', 'waiting L1']);
  });

  test('a failed put away returns the server message', () async {
    final repo = FakeShelfRepository(
      waiting: () async => [kurta],
      write: () async => throw const ApiException('Only 3 are waiting.'),
    );
    final vm = WaitingToShelveViewModel('L1', repo);
    await vm.load();

    expect(await vm.putAway(kurta, shelf('s1'), 9), 'Only 3 are waiting.');
    expect(repo.calls, ['waiting L1', 'putAway']);
  });
}
