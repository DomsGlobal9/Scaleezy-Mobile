import 'package:scaleezy/core/utils/json_parse.dart';
import 'package:scaleezy/features/inventory/data/inventory_models.dart';

class DashboardSummary {
  final int totalProducts;
  final int activeProducts;
  final int criticalStockItems;
  final int totalUnits;

  /// Null when the role lacks `cost:view`.
  final double? inventoryValue;
  final int openPurchaseOrders;
  final int pendingReceipts;
  final int totalSuppliers;
  final List<TransactionItem> recentTransactions;

  const DashboardSummary({
    required this.totalProducts,
    required this.activeProducts,
    required this.criticalStockItems,
    required this.totalUnits,
    required this.inventoryValue,
    required this.openPurchaseOrders,
    required this.pendingReceipts,
    required this.totalSuppliers,
    required this.recentTransactions,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> j) => DashboardSummary(
    totalProducts: asInt(j['totalProducts']),
    activeProducts: asInt(j['activeProducts']),
    criticalStockItems: asInt(j['criticalStockItems']),
    totalUnits: asInt(j['totalUnits']),
    inventoryValue: asMoney(j['inventoryValue']),
    openPurchaseOrders: asInt(j['openPurchaseOrders']),
    pendingReceipts: asInt(j['pendingReceipts']),
    totalSuppliers: asInt(j['totalSuppliers']),
    recentTransactions: asMaps(
      j['recentTransactions'],
    ).map(TransactionItem.fromJson).toList(),
  );
}
