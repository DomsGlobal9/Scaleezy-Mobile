import 'package:scaleezy/features/dashboard/data/dashboard_models.dart';
import 'package:scaleezy/features/dashboard/data/dashboard_repository.dart';
import 'package:scaleezy/features/inventory/data/inventory_models.dart';
import 'package:scaleezy/features/inventory/data/inventory_repository.dart';

import '../products/products_fakes.dart' show offlineClient;

DashboardSummary summary({
  int totalUnits = 120,
  int criticalStockItems = 0,
  Object? inventoryValue,
  List<Map<String, dynamic>> recent = const [],
}) => DashboardSummary.fromJson({
  'totalProducts': 10,
  'activeProducts': 8,
  'criticalStockItems': criticalStockItems,
  'totalUnits': totalUnits,
  'inventoryValue': inventoryValue,
  'openPurchaseOrders': 4,
  'pendingReceipts': 30,
  'totalSuppliers': 3,
  'recentTransactions': recent,
});

/// The shape GET /reports/dashboard-summary answers with.
MoneySummary money({
  Object? companyWideValue,
  int unitsWithoutCost = 0,
  int unitsValuedAtPrice = 0,
  int outOfStockCount = 0,
}) => MoneySummary.fromJson({
  'inventoryValue': 207398.5,
  'companyWideValue': companyWideValue,
  'unitsWithoutCost': unitsWithoutCost,
  'unitsValuedAtPrice': unitsValuedAtPrice,
  'openPoValue': 12000,
  'lowStockCount': 3,
  'outOfStockCount': outOfStockCount,
  'deadStockValue': 0,
  'activeProducts': 42,
});

/// One row of GET /inventory/alerts -> data.alerts.
StockAlert alert(String id, String type, {int quantity = 1}) =>
    StockAlert.fromJson({
      'id': id,
      'type': type,
      'variantId': 'v-$id',
      'productTitle': 'Saree $id',
      'sku': 'SKU-$id',
      'quantity': quantity,
      'reorderLevel': 5,
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

/// Answers with [answer] / [moneyAnswer] / [alerts] and records which calls went out.
class FakeDashboardRepository extends DashboardRepository {
  FakeDashboardRepository(this.answer, {this.moneyAnswer, this.alerts})
    : super(offlineClient());

  Future<DashboardSummary> Function() answer;
  Future<MoneySummary> Function()? moneyAnswer;
  Future<List<StockAlert>> Function()? alerts;
  final calls = <String>[];

  @override
  Future<DashboardSummary> getDashboardSummary() {
    calls.add('summary');
    return answer();
  }

  @override
  Future<MoneySummary> getMoneySummary() {
    calls.add('money');
    return moneyAnswer!();
  }

  @override
  Future<List<StockAlert>> getStockAlerts() {
    calls.add('alerts');
    return alerts!();
  }
}

/// Records the limits asked for and answers with [movements].
class FakeHomeInventoryRepository extends InventoryRepository {
  FakeHomeInventoryRepository({this.movements}) : super(offlineClient());

  Future<List<TransactionItem>> Function()? movements;
  final calls = <String>[];

  @override
  Future<List<TransactionItem>> getTransactions({
    String? variantId,
    int limit = 50,
  }) {
    calls.add('transactions:$limit');
    return movements!();
  }
}
