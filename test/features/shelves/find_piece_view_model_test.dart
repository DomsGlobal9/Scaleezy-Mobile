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

  test('searches every store, and blank text clears the results', () async {
    final repo = FakeShelfRepository(find: (_) async => [found]);
    final vm = FindPieceViewModel(locationId: 'L2', repo: repo);

    await vm.search('saree');
    expect(vm.results, hasLength(1));
    expect(vm.loading, isFalse);
    // Every store is searched; this one is only put first.
    expect(repo.calls, ['find saree @null']);
    expect(vm.placesOf(found).map((p) => p.locationId), ['L2', 'L1']);

    await vm.search('  ');
    expect(vm.results, isNull);
    expect(repo.calls, hasLength(1));
  });

  test('without a store places keep the server order', () {
    final vm = FindPieceViewModel(repo: FakeShelfRepository());
    expect(vm.placesOf(found).map((p) => p.locationId), ['L1', 'L2']);
  });

  test('a failed search shows the server message', () async {
    final repo = FakeShelfRepository(
      find: (_) async => throw const ApiException('The server is busy.'),
    );
    final vm = FindPieceViewModel(repo: repo);

    await vm.search('saree');
    expect(vm.error, 'The server is busy.');
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

  test('typing searches once the person pauses', () async {
    final repo = FakeShelfRepository(find: (_) async => [found]);
    final vm = FindPieceViewModel(repo: repo);

    vm.typed('sa');
    vm.typed('saree');
    await Future<void>.delayed(const Duration(milliseconds: 450));

    expect(repo.calls, ['find saree @null']);
    vm.dispose();
  });
}
