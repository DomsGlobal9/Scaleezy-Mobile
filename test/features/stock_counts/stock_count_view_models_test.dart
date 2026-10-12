import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/features/stock_counts/presentation/view_models/stock_count_view_model.dart';
import 'package:scaleezy/features/stock_counts/presentation/view_models/stock_counts_view_model.dart';

import '../auth/auth_fakes.dart';
import 'stock_counts_fakes.dart';

void main() {
  group('stock counts list', () {
    test('loads every count and how many are open', () async {
      final repo = FakeStockCountRepository(
        list: () async => [
          count('1', status: 'IN_PROGRESS'),
          count('2', status: 'DRAFT'),
          count('3', status: 'COMPLETED', matched: 2, adjusted: 1),
        ],
      );
      final vm = StockCountsViewModel(repo);
      expect(vm.counts, isNull);
      await vm.load();

      expect(vm.counts!.map((c) => c.id), ['1', '2', '3']);
      expect(vm.openCount, 2);
      expect(vm.error, isNull);
    });

    test('a failed load shows the server message', () async {
      final vm = StockCountsViewModel(
        FakeStockCountRepository(
          list: () async => throw const ApiException('No access.'),
        ),
      );
      await vm.load();
      expect(vm.error?.message, 'No access.');
      expect(vm.counts, isNull);
    });

    test('creates a count for the chosen store and category', () async {
      final repo = FakeStockCountRepository(
        create: () async => count('new', status: 'DRAFT'),
      );
      final vm = StockCountsViewModel(repo);
      final error = await vm.create(
        name: 'Kids rack',
        locationId: 'L2',
        category: 'KIDS',
      );

      expect(error, isNull);
      expect(vm.created!.id, 'new');
      expect(vm.creating, isFalse);
      expect(repo.calls, ['create Kids rack L2 KIDS']);
    });

    test('a refused new count keeps the server message', () async {
      const message =
          'There is nothing to count yet: this shop has no products on sale. Add products first.';
      final vm = StockCountsViewModel(
        FakeStockCountRepository(
          create: () async => throw const ApiException(message),
        ),
      );
      expect(await vm.create(name: 'x', locationId: 'L1'), message);
      expect(vm.createError, message);
      expect(vm.created, isNull);
      expect(vm.creating, isFalse);
    });
  });

  group('one count', () {
    Future<(StockCountViewModel, FakeStockCountRepository)> loaded({
      String status = 'IN_PROGRESS',
    }) async {
      final repo = FakeStockCountRepository(
        one: () async => detail(status: status),
      );
      final vm = StockCountViewModel('c1', repo);
      await vm.load();
      return (vm, repo);
    }

    test('loads its lines with totals per filter', () async {
      final (vm, repo) = await loaded();

      expect(repo.calls, ['get c1']);
      expect(vm.count!.status, 'IN_PROGRESS');
      expect(vm.counting, isTrue);
      expect(vm.lines.map((l) => l.title), [
        'Cotton Kurta',
        'Linen Shirt',
        'Silk Saree',
      ]);
      expect(
        (vm.total, vm.counted, vm.uncounted, vm.differences),
        (3, 2, 1, 1),
      );
      expect(vm.countOf('TODO'), 1);
      expect(vm.countOf('DIFF'), 1);
      expect(vm.countOf('ALL'), 3);
    });

    test('a failed load shows the server message', () async {
      final vm = StockCountViewModel(
        'c1',
        FakeStockCountRepository(
          one: () async => throw const ApiException('Stock count not found'),
        ),
      );
      await vm.load();
      expect(vm.error?.message, 'Stock count not found');
      expect(vm.count, isNull);
      expect(vm.visible, isEmpty);
    });

    test('filters and searches by name, SKU or barcode', () async {
      final (vm, _) = await loaded();

      vm.selectFilter('TODO');
      expect(vm.visible.map((l) => l.id), ['a']);
      vm.selectFilter('DIFF');
      expect(vm.visible.map((l) => l.id), ['c']);
      vm.selectFilter('ALL');

      vm.search('  SILK ');
      expect(vm.visible.map((l) => l.id), ['b']);
      vm.search('sku-c');
      expect(vm.visible.map((l) => l.id), ['c']);
      vm.search('8901a');
      expect(vm.visible.map((l) => l.id), ['a']);
      vm.search('');
      expect(vm.visible, hasLength(3));
    });

    test('a scan finds its line by barcode, SKU or variant code', () async {
      final (vm, _) = await loaded();
      expect(vm.find('8901b')?.id, 'b');
      expect(vm.find(' SKU-a ')?.id, 'a');
      expect(vm.find('vc-c')?.id, 'c');
      expect(vm.find('999'), isNull);
      expect(vm.find('  '), isNull);
    });

    test('a saved count takes the server figures and moves filters', () async {
      final (vm, repo) = await loaded();
      // Two sold since the count was made: the server answers the stock at this moment.
      repo.save = (id, n) async => savedLine(id, expected: 2, counted: n);
      vm.selectFilter('TODO');
      expect(vm.visible.map((l) => l.id), ['a']);

      final saving = vm.setCounted('a', 3);
      expect(vm.isSaving('a'), isTrue);
      expect(vm.anySaving, isTrue);
      expect(await saving, isNull);

      expect(repo.calls.last, 'set c1 a 3');
      final a = vm.lines.firstWhere((l) => l.id == 'a');
      expect((a.expected, a.counted, a.difference), (2, 3, 1));
      expect(a.title, 'Cotton Kurta');
      expect(vm.isSaving('a'), isFalse);
      expect(vm.visible, isEmpty);
      expect((vm.counted, vm.differences), (3, 2));
    });

    test('a refused count leaves the line as it was and says why', () async {
      final (vm, repo) = await loaded();
      const message =
          'This audit has already been completed. Start a new one to count again.';
      repo.save = (_, _) async => throw const ApiException(message);

      expect(await vm.setCounted('b', 9), message);
      expect(vm.lines.firstWhere((l) => l.id == 'b').counted, 10);
      expect(vm.lineError('b'), message);
      expect(vm.isSaving('b'), isFalse);

      // A later save that works clears the problem.
      repo.save = (id, n) async => savedLine(id, expected: 10, counted: n);
      expect(await vm.setCounted('b', 9), isNull);
      expect(vm.lineError('b'), isNull);
    });

    test('+1 counts one more piece; clearing puts it back', () async {
      final (vm, repo) = await loaded();
      repo.save = (id, n) async => savedLine(id, expected: 4, counted: n);

      await vm.addOne('a');
      await vm.addOne('a');
      expect(vm.lines.firstWhere((l) => l.id == 'a').counted, 2);
      await vm.setCounted('a', null);
      expect(vm.lines.firstWhere((l) => l.id == 'a').counted, isNull);
      expect(repo.calls.skip(1), ['set c1 a 1', 'set c1 a 2', 'set c1 a null']);
    });

    test('starting a draft opens it for counting', () async {
      final (vm, repo) = await loaded(status: 'DRAFT');
      repo.action = (_) async => count('c1', status: 'IN_PROGRESS');
      expect(vm.counting, isFalse);

      expect(await vm.start(), isNull);
      expect(repo.calls.last, 'start c1');
      expect(vm.counting, isTrue);
      expect(vm.lines, hasLength(3));
    });

    test('finishing keeps the lines and shows the result', () async {
      final (vm, repo) = await loaded();
      repo.action = (_) async => count(
        'c1',
        status: 'COMPLETED',
        matched: 1,
        adjusted: 1,
        accuracy: '50',
      );

      expect(await vm.complete(), isNull);
      expect(repo.calls.last, 'complete c1');
      expect(vm.count!.status, 'COMPLETED');
      expect(vm.count!.accuracy, 50);
      expect(vm.count!.adjustedItems, 1);
      expect(vm.counting, isFalse);
      expect(vm.lines, hasLength(3));
      expect(vm.busy, isFalse);
    });

    test('a refused finish keeps the count open', () async {
      final (vm, repo) = await loaded();
      repo.action = (_) async =>
          throw const ApiException('This count has already been cancelled.');

      expect(await vm.complete(), 'This count has already been cancelled.');
      expect(vm.count!.status, 'IN_PROGRESS');
      expect(vm.busy, isFalse);
    });

    test('only the owner may cancel, and only an open count', () async {
      final (vm, repo) = await loaded();
      expect(vm.canCancel(person(owner: true)), isTrue);
      expect(vm.canCancel(person()), isFalse);
      expect(vm.canCancel(null), isFalse);

      repo.action = (_) async => count('c1', status: 'CANCELLED');
      expect(await vm.cancel(), isNull);
      expect(repo.calls.last, 'cancel c1');
      expect(vm.canCancel(person(owner: true)), isFalse);

      final (done, _) = await loaded(status: 'COMPLETED');
      expect(done.canCancel(person(owner: true)), isFalse);
    });
  });
}
