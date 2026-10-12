import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/features/inventory/presentation/view_models/stock_movement_view_model.dart';

import 'inventory_fakes.dart';

void main() {
  StockMovementViewModel movement(
    FakeInventoryRepository repo, {
    bool isStockIn = true,
  }) => StockMovementViewModel(
    variantId: 'v1',
    isStockIn: isStockIn,
    inventory: repo,
  );

  test('stock in sends quantity, reason and cost', () async {
    final repo = FakeInventoryRepository();
    final vm = movement(repo)
      ..quantity = ' 3 '
      ..cost = '249.5'
      ..reason = 'RETURN';

    expect(await vm.save(), isNull);
    expect(repo.calls.single, {
      'call': 'stockIn',
      'variantId': 'v1',
      'quantity': 3,
      'reason': 'RETURN',
      'unitCost': 249.5,
      'notes': null,
    });
  });

  test('stock in without a cost sends none', () async {
    final repo = FakeInventoryRepository();
    expect(await movement(repo).save(), isNull);
    expect(repo.calls.single['unitCost'], isNull);
    expect(repo.calls.single['reason'], 'PURCHASE');
    expect(repo.calls.single['quantity'], 1);
  });

  test('stock out sends its own reasons and no cost', () async {
    final repo = FakeInventoryRepository();
    final vm = movement(repo, isStockIn: false);
    expect(vm.reasons, ['DAMAGE', 'SAMPLE', 'RETURN_TO_VENDOR']);
    expect(vm.reason, 'DAMAGE');
    vm
      ..quantity = '2'
      ..reason = 'SAMPLE';

    expect(await vm.save(), isNull);
    expect(repo.calls.single, {
      'call': 'stockOut',
      'variantId': 'v1',
      'quantity': 2,
      'reason': 'SAMPLE',
      'notes': null,
    });
  });

  test('a bad quantity or cost is caught before sending', () async {
    final repo = FakeInventoryRepository();
    final vm = movement(repo)..quantity = '0';
    const qtyMessage = 'Enter how many pieces, as a whole number above zero.';
    expect(await vm.save(), qtyMessage);
    vm.quantity = '1.5';
    expect(await vm.save(), qtyMessage);

    vm
      ..quantity = '2'
      ..cost = 'abc';
    expect(await vm.save(), 'That purchase cost is not a number.');
    expect(vm.error, 'That purchase cost is not a number.');
    expect(repo.calls, isEmpty);
    expect(vm.busy, isFalse);
  });

  test('a server error is returned and the form stays usable', () async {
    final repo = FakeInventoryRepository()
      ..fail = const ApiException('Not enough stock');
    final vm = movement(repo, isStockIn: false);

    expect(await vm.save(), 'Not enough stock');
    expect(vm.error, 'Not enough stock');
    expect(vm.busy, isFalse);
  });

  test('quick-add pills stay between 1 and 9999', () {
    final vm = movement(FakeInventoryRepository());
    expect(vm.addQuantity(5), '6');
    vm.quantity = 'x';
    expect(vm.addQuantity(1), '1');
    vm.quantity = '9998';
    expect(vm.addQuantity(25), '9999');
  });
}
