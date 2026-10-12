import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/features/shelves/data/shelf_models.dart';
import 'package:scaleezy/features/shelves/presentation/view_models/find_piece_view_model.dart';

import 'shelves_fakes.dart';

WherePlace place(String locationId) => WherePlace(
  locationId: locationId,
  location: 'Store $locationId',
  total: 1,
  held: 0,
  usesShelves: true,
  shelves: const [],
  notShelved: 0,
);

void main() {
  final found = WhereItem(item: item('v1'), places: [place('L1'), place('L2')]);

  test('searches this store, and blank text clears the results', () async {
    final repo = FakeShelfRepository(find: (_) async => [found]);
    final vm = FindPieceViewModel(locationId: 'L2', repo: repo);

    await vm.search(' saree ');
    expect(vm.results, hasLength(1));
    expect(vm.query, 'saree');
    expect(vm.loading, isFalse);
    expect(repo.calls, ['find saree @L2']);
    // This store's places come first.
    expect(vm.placesOf(found).map((p) => p.locationId), ['L2', 'L1']);

    await vm.search('  ');
    expect(vm.results, isNull);
    expect(repo.calls, hasLength(1));
  });

  test('"Look in every location" searches again without a store', () async {
    final repo = FakeShelfRepository(find: (_) async => [found]);
    final vm = FindPieceViewModel(locationId: 'L2', repo: repo);
    await vm.search('saree');

    vm.setEverywhere(true, 'saree');
    await pumpEventQueue();
    expect(vm.everywhere, isTrue);
    vm.setEverywhere(true, 'saree'); // unchanged: no new search
    vm.setEverywhere(false, 'saree');
    await pumpEventQueue();

    expect(repo.calls, [
      'find saree @L2',
      'find saree @null',
      'find saree @L2',
    ]);
  });

  test('without a store places keep the server order', () {
    final vm = FindPieceViewModel(repo: FakeShelfRepository());
    expect(vm.placesOf(found).map((p) => p.locationId), ['L1', 'L2']);
  });

  test('a failed search keeps the server error', () async {
    final repo = FakeShelfRepository(
      find: (_) async => throw const ApiException('The server is busy.'),
    );
    final vm = FindPieceViewModel(repo: repo);

    await vm.search('saree');
    expect(vm.error?.message, 'The server is busy.');
    expect(vm.loading, isFalse);
  });

  test('an answer for older text is dropped', () async {
    final slow = Completer<List<WhereItem>>();
    final repo = FakeShelfRepository(
      find: (q) => q == 'old' ? slow.future : Future.value([found]),
    );
    final vm = FindPieceViewModel(repo: repo);

    final first = vm.search('old');
    await vm.search('new');
    slow.complete(const []);
    await first;

    expect(vm.results, [found]);
  });

  test('typing searches once the person pauses for 250 ms', () async {
    final repo = FakeShelfRepository(find: (_) async => [found]);
    final vm = FindPieceViewModel(repo: repo);

    vm.typed('sa');
    vm.typed('saree');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(repo.calls, isEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(repo.calls, ['find saree @null']);
    vm.dispose();
  });
}
