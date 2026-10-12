import 'package:scaleezy/features/suppliers/data/supplier_models.dart';
import 'package:scaleezy/features/suppliers/data/supplier_repository.dart';

import '../../support/fake_api.dart';

export '../../support/fake_api.dart' show offlineClient;

Supplier supplier(
  String id, {
  required String name,
  String? phone,
  bool active = true,
}) => Supplier.fromJson({
  'id': id,
  'supplierCode': 'SUP-$id',
  'name': name,
  'phone': ?phone,
  'isActive': active,
  '_count': {'purchaseOrders': 2},
});

class FakeSupplierRepository extends SupplierRepository {
  FakeSupplierRepository(this.answer) : super(offlineClient());

  Future<List<Supplier>> Function() answer;
  var calls = 0;

  @override
  Future<List<Supplier>> suppliers() {
    calls++;
    return answer();
  }
}
