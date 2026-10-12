import 'package:scaleezy/features/dashboard/data/dashboard_models.dart';
import 'package:scaleezy/features/dashboard/data/dashboard_repository.dart';
import 'package:scaleezy/features/inventory/data/inventory_models.dart';
import 'package:scaleezy/features/inventory/data/inventory_repository.dart';
import 'package:scaleezy/features/products/data/product_models.dart';

import '../products/products_fakes.dart' show offlineClient;

DashboardSummary summary({
  int totalUnits = 120,
  int criticalStockItems = 0,
  List<Map<String, dynamic>> recent = const [],
}) => DashboardSummary.fromJson({
  'totalProducts': 10,
  'activeProducts': 8,
  'criticalStockItems': criticalStockItems,
  'totalUnits': totalUnits,
  'recentTransactions': recent,
});

Map<String, dynamic> movementJson(String id, int quantity, DateTime at) => {
  'id': id,
  'type': quantity > 0 ? 'IN' : 'OUT',
  'quantity': quantity,
  'productTitle': 'Saree',
  'sku': 'SKU-$id',
  'createdAt': at.toIso8601String(),
};

TransactionItem movement(String id, int quantity, DateTime at) =>
    TransactionItem.fromJson(movementJson(id, quantity, at));

class FakeDashboardRepository extends DashboardRepository {
  FakeDashboardRepository(this.answer) : super(offlineClient());

  Future<DashboardSummary> Function() answer;

  @override
  Future<DashboardSummary> getDashboardSummary() => answer();
}

/// Records the limits asked for and answers with [lowStock] / [movements].
class FakeHomeInventoryRepository extends InventoryRepository {
  FakeHomeInventoryRepository({this.lowStock, this.movements})
    : super(offlineClient());

  Future<List<VariantItem>> Function()? lowStock;
  Future<List<TransactionItem>> Function()? movements;
  final calls = <String>[];

  @override
  Future<List<VariantItem>> getLowStockVariants({int limit = 5}) {
    calls.add('lowStock:$limit');
    return lowStock!();
  }

  @override
  Future<List<TransactionItem>> getTransactions({
    String? variantId,
    int limit = 50,
  }) {
    calls.add('transactions:$limit');
    return movements!();
  }
}
