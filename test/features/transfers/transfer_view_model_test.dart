import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/features/products/data/product_models.dart';
import 'package:scaleezy/features/transfers/presentation/view_models/transfer_view_model.dart';

import 'transfers_fakes.dart';

final main1 = store('L1');
final godown = store('L2');
final branch = store('L3');
final online = store('W', type: 'ONLINE');

/// Started between L1 and L2, with [stock] answering what L1 holds.
TransferViewModel vmWith({
  FakeTransferRepository? repo,
  Future<List<VariantItem>> Function(String q)? lookup,
}) => TransferViewModel(
  repo: repo ?? FakeTransferRepository(),
  products: FakeProductRepository(lookup ?? (_) async => []),
)..start(main1, [main1, godown]);

void main() {
  group('stores', () {
    test('starts from the selected store, else the first real one', () {
      final vm = TransferViewModel(
        repo: FakeTransferRepository(),
        products: FakeProductRepository((_) async => []),
      );
      vm.start(godown, [online, main1, godown]);
      expect(vm.from, godown);
      vm.start(null, [online, main1, godown]);
      expect(vm.from, main1);
    });

    test(
      'the only other store is the destination; with more, the person picks',
      () {
        final vm = vmWith();
        expect((vm.from, vm.to), (main1, godown));
        vm.start(null, [main1, godown, branch]);
        expect(vm.to, isNull);
        expect(vm.destinations, [godown, branch]);
      },
    );

    test(
      'changing the source empties the list; picking the destination swaps',
      () {
        final vm = vmWith()..add(stock('v1'));
        vm.pickFrom(godown);
        expect((vm.from, vm.to), (godown, main1));
        expect(vm.lines, isEmpty);
      },
    );
  });

  group('adding items', () {
    test('search shows only what the source has pieces of', () async {
      final repo = FakeTransferRepository(
        stock: (_, _) async => [stock('v1'), stock('v2', quantity: 0)],
      );
      final vm = vmWith(repo: repo);
      await vm.search('saree');
      expect(repo.searches, ['L1 saree']);
      expect(vm.results!.map((r) => r.variantId), ['v1']);
      vm.clearSearch();
      expect(vm.results, isNull);
    });

    test('a scan adds one piece, and each scan after adds one more', () async {
      final repo = FakeTransferRepository(
        stock: (_, _) async => [stock('v9'), stock('v1', quantity: 2)],
      );
      final products = <String>[];
      final vm = vmWith(
        repo: repo,
        lookup: (q) async {
          products.add(q);
          return [piece('v1')];
        },
      );

      expect(await vm.scan('890v1'), '+1  Saree  (1 of 2)');
      // The second scan of the same tag needs no lookup.
      expect(await vm.scan('890v1'), '+1  Saree  (2 of 2)');
      expect(
        await vm.scan('890v1'),
        'All 2 of Saree at Store L1 are in the list.',
      );
      expect(products, ['890v1']);
      expect(repo.searches, ['L1 SKU-v1']);
      expect((vm.lines.single.variantId, vm.qty('v1')), ('v1', 2));
    });

    test('a scan that finds nothing, or nothing here, says so', () async {
      final vm = vmWith(
        repo: FakeTransferRepository(
          stock: (_, _) async => [stock('v1', quantity: 0)],
        ),
        lookup: (q) async => q == 'known' ? [piece('v1')] : [],
      );
      expect(await vm.scan('nope'), 'No product matches "nope".');
      expect(await vm.scan('known'), 'Store L1 has none of Saree.');
      expect(vm.lines, isEmpty);
    });

    test('a failed lookup shows the server message', () async {
      final vm = vmWith(
        lookup: (_) async =>
            throw const ApiException('Your role does not allow this.'),
      );
      expect(await vm.scan('x'), 'Your role does not allow this.');
    });

    test('quantity stays between one and what the source has', () {
      final vm = vmWith()..add(stock('v1', quantity: 3));
      vm.setQty('v1', 9);
      expect(vm.qty('v1'), 3);
      vm.setQty('v1', 0);
      expect(vm.qty('v1'), 1);
      vm.remove('v1');
      expect(vm.lines, isEmpty);
      expect(vm.pieces, 0);
    });
  });

  group('moving', () {
    test('refuses with the server wording what it can check first', () {
      final vm = vmWith();
      expect(vm.validate(), 'Add at least one item to move.');

      vm.add(stock('v1'));
      vm.start(main1, [main1, godown, branch]); // no destination yet
      expect(
        vm.validate(),
        'Choose the store the stock leaves and the store it goes to.',
      );

      vm.pickTo(main1);
      expect(
        vm.validate(),
        'Origin and destination locations must be different',
      );
      expect(vm.error, 'Origin and destination locations must be different');
    });

    test('moves the list and keeps what happened for the result', () async {
      final repo = FakeTransferRepository(send: () async {});
      final vm = vmWith(repo: repo)
        ..add(stock('v1'))
        ..add(stock('v1'))
        ..add(stock('v2'));

      expect(await vm.move(' window '), isTrue);
      expect(repo.sent.single, {
        'from': 'L1',
        'to': 'L2',
        'quantities': {'v1': 2, 'v2': 1},
        'notes': ' window ',
      });
      final moved = vm.moved!;
      expect(
        (moved.pieces, moved.items, moved.from, moved.to),
        (3, 2, main1, godown),
      );
      expect(vm.lines, isEmpty);
      expect(vm.busy, isFalse);

      vm.startOver();
      expect(vm.moved, isNull);
    });

    test('a refusal keeps the list and the server message', () async {
      final vm = vmWith(
        repo: FakeTransferRepository(
          send: () async => throw const ApiException(
            'Only 1 of this item is free here: 4 are held for orders. Cancel or send out those orders first.',
            statusCode: 409,
          ),
        ),
      )..add(stock('v1'));

      expect(await vm.move(''), isFalse);
      expect(vm.error, startsWith('Only 1 of this item is free here'));
      expect((vm.lines.length, vm.moved, vm.busy), (1, null, false));
    });

    test(
      'no answer warns before a second try, which would move it twice',
      () async {
        final vm = vmWith(
          repo: FakeTransferRepository(
            send: () async => throw const ApiException(
              'The server is taking too long. Check the connection and try again.',
            ),
          ),
        )..add(stock('v1'));

        expect(await vm.move(''), isFalse);
        expect(vm.error, contains('may have moved already'));
      },
    );

    test('a second tap while moving is not sent', () async {
      final answer = Completer<void>();
      final repo = FakeTransferRepository(send: () => answer.future);
      final vm = vmWith(repo: repo)..add(stock('v1'));

      final first = vm.move('');
      expect(vm.busy, isTrue);
      expect(await vm.move(''), isFalse);
      answer.complete();
      expect(await first, isTrue);
      expect(repo.sent, hasLength(1));
    });
  });
}
