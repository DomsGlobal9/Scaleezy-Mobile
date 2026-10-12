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

  test('loads, hides inactive ones until asked, and searches', () async {
    final vm = SuppliersViewModel(FakeSupplierRepository(() async => all));
    expect(vm.all, isNull);
    await vm.load();

    expect(vm.visible.map((s) => s.id), ['1', '2']);
    expect(vm.inactive, 1);

    vm.setShowInactive(true);
    expect(vm.visible, hasLength(3));

    vm.search(' 98000 ');
    expect(vm.visible.map((s) => s.id), ['1']);
    vm.search('sup-2');
    expect(vm.visible.map((s) => s.id), ['2']);
    vm.search('');
    expect(vm.visible, hasLength(3));
  });

  test('a failed load shows the server message', () async {
    final vm = SuppliersViewModel(
      FakeSupplierRepository(
        () async => throw const ApiException('No access.'),
      ),
    );
    await vm.load();
    expect(vm.error, 'No access.');
    expect(vm.all, isNull);
  });
}
