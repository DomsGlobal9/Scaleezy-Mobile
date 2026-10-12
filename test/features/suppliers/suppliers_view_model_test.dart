import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/features/suppliers/presentation/view_models/suppliers_view_model.dart';

import 'suppliers_fakes.dart';

void main() {
  final all = [
    supplier('1', name: 'Weavers Co', phone: '9800000000'),
    supplier('2', name: 'Loom House'),
    supplier('3', name: 'Old Mill', active: false),
  ];

  test('loads every supplier, inactive ones included, and searches', () async {
    final vm = SuppliersViewModel(FakeSupplierRepository(() async => all));
    expect(vm.all, isNull);
    await vm.load();

    // As the website: inactive suppliers are listed (and labelled), not hidden.
    expect(vm.visible.map((s) => s.id), ['1', '2', '3']);

    vm.search(' 98000 ');
    expect(vm.visible.map((s) => s.id), ['1']);
    vm.search('sup-2');
    expect(vm.visible.map((s) => s.id), ['2']);
    vm.search('');
    expect(vm.visible, hasLength(3));
  });

  test('a failed load keeps the failure for the screen', () async {
    final vm = SuppliersViewModel(
      FakeSupplierRepository(
        () async => throw const ApiException('No access.', statusCode: 403),
      ),
    );
    await vm.load();
    expect(vm.error, 'No access.');
    expect(vm.failure!.isForbidden, isTrue);
    expect(vm.all, isNull);
  });
}
