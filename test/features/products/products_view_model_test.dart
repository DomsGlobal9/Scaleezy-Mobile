import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/models/paged.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/features/products/data/product_models.dart';
import 'package:scaleezy/features/products/presentation/view_models/products_view_model.dart';

import 'products_fakes.dart';

Paged<ProductItem> pageOf(int page, int pages, List<String> ids, int total) =>
    Paged(
      items: [for (final id in ids) product(id)],
      page: page,
      pages: pages,
      total: total,
    );

void main() {
  test('reload loads page one, loadMore appends until the last page', () async {
    final repo = FakeProductRepository(
      answer: (page) async =>
          page == 1 ? pageOf(1, 2, ['a', 'b'], 3) : pageOf(2, 2, ['c'], 3),
    );
    final vm = ProductsViewModel(repo);

    await vm.reload();
    expect(vm.products.map((p) => p.id), ['a', 'b']);
    expect(vm.total, 3);
    expect(vm.hasMore, isTrue);

    await vm.loadMore();
    expect(vm.products.map((p) => p.id), ['a', 'b', 'c']);
    expect(vm.hasMore, isFalse);

    await vm.loadMore(); // nothing left to ask for
    expect(repo.calls, hasLength(2));
    expect(vm.loading, isFalse);
  });

  test('a page that arrives after a reload is dropped', () async {
    final slow = Completer<Paged<ProductItem>>();
    var call = 0;
    final repo = FakeProductRepository(
      answer: (_) =>
          ++call == 1 ? slow.future : Future.value(pageOf(1, 1, ['new'], 1)),
    );
    final vm = ProductsViewModel(repo);

    final first = vm.reload();
    await vm.reload();
    slow.complete(pageOf(1, 1, ['old'], 1));
    await first;

    expect(vm.products.map((p) => p.id), ['new']);
  });

  test('search, category and filters reach the repository', () async {
    final repo = FakeProductRepository(
      answer: (_) async => pageOf(1, 1, ['a'], 1),
    );
    final vm = ProductsViewModel(repo);
    expect(vm.isFiltered, isFalse);

    vm.applyFilters(ProductSort.priceLow, 'ARCHIVED');
    vm.selectCategory('MEN');
    vm.search('silk');
    expect(vm.query, 'silk');
    await Future<void>.delayed(const Duration(milliseconds: 500));

    expect(repo.calls.last, {
      'page': 1,
      'search': 'silk',
      'category': 'MEN',
      'status': 'ARCHIVED',
      'sortBy': 'basePrice',
      'order': 'asc',
    });
    expect(vm.isFiltered, isTrue);

    vm.selectCategory('ALL');
    await Future<void>.delayed(Duration.zero);
    expect(repo.calls.last['category'], isNull);
    vm.dispose();
  });

  test(
    'a failed page keeps what loaded and shows the server message',
    () async {
      final repo = FakeProductRepository(
        answer: (page) async => page == 1
            ? pageOf(1, 2, ['a'], 2)
            : throw const ApiException('The server is busy.'),
      );
      final vm = ProductsViewModel(repo);

      await vm.reload();
      await vm.loadMore();

      expect(vm.products.map((p) => p.id), ['a']);
      expect(vm.error, 'The server is busy.');
      expect(vm.loading, isFalse);
    },
  );
}
