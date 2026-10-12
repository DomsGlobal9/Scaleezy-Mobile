import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/features/products/presentation/view_models/product_detail_view_model.dart';

import 'products_fakes.dart';

void main() {
  final saree = product(
    'p1',
    totalUnits: 40,
    variantCount: 9,
    lowStockVariants: 4,
  );
  final rows = [
    variant('v1', colour: 'Red', size: 'S', quantity: 1, reorderLevel: 5),
    variant('v2', colour: 'Red', size: 'M', quantity: 6),
    variant('v3', colour: 'Blue', quantity: 0),
  ];

  test('numbers come from the list summary until the variants load', () async {
    final vm = ProductDetailViewModel(
      saree,
      products: FakeProductRepository(variants: () async => rows),
      inventory: FakeInventoryRepository(),
    );
    expect((vm.variantCount, vm.pieces, vm.lowOrOut), (9, 40, 4));
    expect(vm.warnLow, isFalse);

    await vm.load();
    expect((vm.variantCount, vm.pieces, vm.lowOrOut), (3, 7, 2));
    expect(vm.warnLow, isTrue);
    expect(vm.colours.map((c) => c.$1), ['Red', 'Blue']);
  });

  test('choosing a colour shows only its sizes', () async {
    final vm = ProductDetailViewModel(
      saree,
      products: FakeProductRepository(variants: () async => rows),
      inventory: FakeInventoryRepository(),
    );
    await vm.load();

    vm.selectColour('Red');
    expect(vm.visibleVariants.map((v) => v.id), ['v1', 'v2']);
    vm.selectColour(null);
    expect(vm.visibleVariants, hasLength(3));
  });

  test('moving stock reloads and marks the product changed', () async {
    var loads = 0;
    final inventory = FakeInventoryRepository();
    final vm = ProductDetailViewModel(
      saree,
      products: FakeProductRepository(
        variants: () async {
          loads++;
          return rows;
        },
      ),
      inventory: inventory,
    );
    await vm.load();
    expect(vm.changed, isFalse);

    await vm.stockMoved();
    expect(vm.changed, isTrue);
    expect(loads, 2);

    await vm.history('v2');
    expect(inventory.historyFor, ['v2']);
  });

  test('a failed load shows the server message', () async {
    final vm = ProductDetailViewModel(
      saree,
      products: FakeProductRepository(
        variants: () async => throw const ApiException('Not found.'),
      ),
      inventory: FakeInventoryRepository(),
    );
    await vm.load();
    expect(vm.error?.message, 'Not found.');
    expect(vm.variants, isNull);
  });
}
