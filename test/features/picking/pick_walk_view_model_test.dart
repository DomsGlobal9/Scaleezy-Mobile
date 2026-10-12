import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/features/picking/data/picking_models.dart';
import 'package:scaleezy/features/picking/presentation/view_models/pick_walk_view_model.dart';

import 'picking_fakes.dart';

/// Order o1 needs 3 of v1 (2 on sp1, 1 on sp2) and 1 of v2 not on a shelf; o2 needs 1 of v3.
PickList twoOrders() => listOf(
  [
    stop('sp1', [
      pick('o1', 'i1', 2),
      pick('o2', 'i9', 1, v: 'v3'),
    ], label: 'K7Q2M9XA'),
    stop('sp2', [pick('o1', 'i1', 1)]),
  ],
  notShelved: [pick('o1', 'i2', 1, v: 'v2')],
  orders: const {'o1': 'SO-o1', 'o2': 'SO-o2'},
);

Future<(PickWalkViewModel, FakePickingRepository)> walk({
  PickList Function()? list,
  Future<void> Function()? notFound,
  Future<void> Function(String orderId)? send,
}) async {
  final repo = FakePickingRepository(
    list: (_) async => (list ?? twoOrders)(),
    notFound: notFound ?? () async {},
    send: send ?? (_) async {},
  );
  final vm = PickWalkViewModel(
    locationId: 'L1',
    orderIds: const ['o1', 'o2'],
    repo: repo,
  );
  await vm.load();
  return (vm, repo);
}

void main() {
  test('builds the walk: shelves in order, then pieces on no shelf', () async {
    final (vm, repo) = await walk();

    expect(repo.calls, ['list L1 o1,o2']);
    expect(vm.tasks.map((t) => t.key), [
      'sp1|i1',
      'sp1|i9',
      'sp2|i1',
      'loose|i2',
    ]);
    expect(vm.current?.key, 'sp1|i1');
    expect(vm.doneCount, 0);
    expect(vm.readyPieces, 0);
  });

  test('a failed list shows the server message', () async {
    final repo = FakePickingRepository(
      list: (_) async => throw const ApiException(
        'SO-o1 is dispatched, so there is nothing to pick for it.',
      ),
    );
    final vm = PickWalkViewModel(
      locationId: 'L1',
      orderIds: const ['o1'],
      repo: repo,
    );
    await vm.load();

    expect(vm.list, isNull);
    expect(
      vm.error,
      'SO-o1 is dispatched, so there is nothing to pick for it.',
    );
  });

  test('marks pieces picked, never more than the line needs', () async {
    final (vm, _) = await walk();
    final first = vm.tasks.first;

    vm.setPicked(first, 1);
    expect(vm.isDone(first), isFalse);
    vm.setPicked(first, 9);
    expect(vm.picked(first), 2);
    vm.setPicked(first, -1);
    expect(vm.picked(first), 0);

    vm.pickAll(first);
    expect(vm.isDone(first), isTrue);
    expect(vm.current?.key, 'sp1|i9');
    expect((vm.doneCount, vm.readyPieces, vm.readyOrders), (1, 2, 1));

    for (final t in vm.tasks) {
      vm.pickAll(t);
    }
    expect(vm.allDone, isTrue);
    expect(vm.current, isNull);
  });

  test('scanning checks the shelf label and counts pieces', () async {
    final (vm, _) = await walk();

    expect(vm.scan('SEZ:K7Q2M9XA'), 'At SP1. Now scan the item.');
    expect(vm.scan('sez: zzzzzzzz'), 'That is not SP1.');
    expect(
      vm.scan('nope'),
      '"nope" is not on this pick list, or all of it is picked.',
    );

    // v1 is on two shelves: the current line counts first.
    expect(vm.scan('890v1'), '+1  Saree v1  (1/2)');
    expect(vm.scan('SKU-v1'), '+1  Saree v1  (2/2)');
    expect(vm.picked(vm.task('sp1|i1')!), 2);
    expect(vm.scan('890v1'), '+1  Saree v1  (1/1)');
    expect(vm.picked(vm.task('sp2|i1')!), 1);
    expect(
      vm.scan('890v1'),
      '"890v1" is not on this pick list, or all of it is picked.',
    );

    // A line on no shelf has no label to check.
    vm.pickAll(vm.task('sp1|i9')!);
    expect(vm.current?.key, 'loose|i2');
    expect(
      vm.scan('SEZ:K7Q2M9XA'),
      'This piece is not on a shelf; scan the item.',
    );
    vm.scan('890v2');
    expect(vm.scan('890v2'), 'Everything is picked.');
  });

  test('reporting not found records the rest of the line as missing', () async {
    final (vm, repo) = await walk();
    final first = vm.task('sp1|i1')!;
    vm.setPicked(first, 1);

    expect(await vm.reportNotFound(first), isNull);
    expect(repo.calls.last, 'notFound sp1 v1 1');
    expect(vm.missing(first), 1);
    expect(vm.isDone(first), isTrue);
    // What was found is kept and still goes out.
    expect(vm.picked(first), 1);
    expect(vm.readyPieces, 1);

    // Nothing left to report, and a line on no shelf cannot be reported.
    expect(await vm.reportNotFound(first), isNull);
    expect(await vm.reportNotFound(vm.task('loose|i2')!), isNull);
    expect(repo.calls.where((c) => c.startsWith('notFound')).length, 1);
  });

  test('a refused not-found report changes nothing', () async {
    final (vm, _) = await walk(
      notFound: () async =>
          throw const ApiException('That shelf was not found.'),
    );
    final first = vm.task('sp1|i1')!;

    expect(await vm.reportNotFound(first), 'That shelf was not found.');
    expect(vm.missing(first), 0);
    expect(vm.isDone(first), isFalse);
    expect(vm.reporting, isFalse);
  });

  test('sends out each order with the shelves its pieces came from', () async {
    final (vm, repo) = await walk();
    vm.pickAll(vm.task('sp1|i1')!); // 2 from sp1
    vm.pickAll(vm.task('sp2|i1')!); // 1 from sp2
    vm.pickAll(vm.task('loose|i2')!); // 1 from no shelf
    // Nothing picked for o2, so it is not sent.

    final result = await vm.sendOut();

    expect(result?.sent, 1);
    expect(result?.problems, isEmpty);
    expect(repo.calls.where((c) => c.startsWith('dispatch')), ['dispatch o1']);
    expect(repo.dispatched.single, {
      'salesOrderId': 'o1',
      'items': [
        {
          'salesOrderItemId': 'i1',
          'quantity': 3,
          'fromSpots': [
            {'spotId': 'sp1', 'quantity': 2},
            {'spotId': 'sp2', 'quantity': 1},
          ],
        },
        {'salesOrderItemId': 'i2', 'quantity': 1},
      ],
    });
  });

  test('a refused order is reported and the rest still go out', () async {
    final (vm, repo) = await walk(
      send: (id) async => id == 'o2'
          ? throw const ApiException(
              'Cannot dispatch 1. Only 0 reserved remaining.',
            )
          : null,
    );
    for (final t in vm.tasks) {
      vm.pickAll(t);
    }

    final result = await vm.sendOut();
    expect(result?.sent, 1);
    expect(result?.problems, [
      'SO-o2: Cannot dispatch 1. Only 0 reserved remaining.',
    ]);
    expect(repo.calls.where((c) => c.startsWith('dispatch')), [
      'dispatch o1',
      'dispatch o2',
    ]);
  });

  test('when nothing went out, sending can be tried again', () async {
    var fail = true;
    final (vm, repo) = await walk(
      send: (_) async =>
          fail ? throw const ApiException('Cannot reach the server.') : null,
    );
    vm.pickAll(vm.task('sp1|i9')!);

    final first = await vm.sendOut();
    expect(first?.sent, 0);
    expect(first?.problems, ['SO-o2: Cannot reach the server.']);
    expect(vm.sending, isFalse);

    fail = false;
    expect((await vm.sendOut())?.sent, 1);
    expect(repo.dispatched.length, 2);
  });

  test(
    'never dispatches twice: not while sending, not after it went out',
    () async {
      final gate = Completer<void>();
      final (vm, repo) = await walk(send: (_) => gate.future);
      vm.pickAll(vm.task('sp1|i1')!);

      final running = vm.sendOut();
      expect(vm.sending, isTrue);
      expect(await vm.sendOut(), isNull); // a second press while the first runs
      gate.complete();
      expect((await running)?.sent, 1);

      expect(await vm.sendOut(), isNull); // and after it went out
      expect(repo.dispatched.length, 1);
      expect(vm.sending, isTrue);
    },
  );
}
