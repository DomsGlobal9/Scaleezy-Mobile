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

/// GET /reports/dashboard-summary (report:financial): the website's money tiles. Stock figures
/// are for the selected store; [companyWideValue] is the whole business, sent only when it says
/// something new (a store is selected and the shop has more than one). The open PO value covers
/// sent and part-received orders, not drafts.
class MoneySummary {
  final double inventoryValue;
  final double? companyWideValue;

  /// Pieces counted at ₹0 (nothing known) / at their selling price (no cost known).
  final int unitsWithoutCost;
  final int unitsValuedAtPrice;
  final double openPoValue;

  /// Low and out of stock, counted apart: low never includes the sold-out ones.
  final int lowStockCount;
  final int outOfStockCount;
  final double deadStockValue;
  final int activeProducts;

  const MoneySummary({
    required this.inventoryValue,
    this.companyWideValue,
    this.unitsWithoutCost = 0,
    this.unitsValuedAtPrice = 0,
    required this.openPoValue,
    required this.lowStockCount,
    this.outOfStockCount = 0,
    required this.deadStockValue,
    required this.activeProducts,
  });

  factory MoneySummary.fromJson(Map<String, dynamic> j) => MoneySummary(
    inventoryValue: asMoney(j['inventoryValue']) ?? 0,
    companyWideValue: asMoney(j['companyWideValue']),
    unitsWithoutCost: asInt(j['unitsWithoutCost']),
    unitsValuedAtPrice: asInt(j['unitsValuedAtPrice']),
    openPoValue: asMoney(j['openPoValue']) ?? 0,
    lowStockCount: asInt(j['lowStockCount']),
    outOfStockCount: asInt(j['outOfStockCount']),
    deadStockValue: asMoney(j['deadStockValue']) ?? 0,
    activeProducts: asInt(j['activeProducts']),
  );
}

/// One unresolved stock alert from GET /inventory/alerts -> data.alerts[], for the selected
/// store. [type] is LOW_STOCK, OUT_OF_STOCK or another kind the home list ignores.
class StockAlert {
  final String id;
  final String type;
  final String variantId;

  /// Null on an alert whose variant is gone; the row then opens nothing.
  final String? productId;
  final String productTitle;
  final String sku;
  final int quantity;
  final int reorderLevel;

  const StockAlert({
    required this.id,
    required this.type,
    required this.variantId,
    this.productId,
    required this.productTitle,
    required this.sku,
    required this.quantity,
    required this.reorderLevel,
  });

  bool get isOutOfStock => quantity <= 0;

  factory StockAlert.fromJson(Map<String, dynamic> j) => StockAlert(
    id: asString(j['id']),
    type: asString(j['type']),
    variantId: asString(j['variantId']),
    productId: asOptString(j['productId']),
    productTitle: asString(j['productTitle'] ?? j['variantName']),
    sku: asString(j['sku']),
    quantity: asInt(j['quantity']),
    reorderLevel: asInt(j['reorderLevel']),
  );
}
