class ProductItem {
  final String id;
  final String title;
  final String productCode;
  final String category;
  final String productType;
  final String fabric;
  final double basePrice;
  final int totalUnits;
  final int variantCount;
  final String status;
  final List<VariantItem> variants;

  const ProductItem({
    required this.id,
    required this.title,
    required this.productCode,
    required this.category,
    required this.productType,
    required this.fabric,
    required this.basePrice,
    required this.totalUnits,
    required this.variantCount,
    required this.status,
    this.variants = const [],
  });
}

class VariantItem {
  final String id;
  final String sku;
  final String barcode;
  final String size;
  final String colorName;
  final int colorHex;
  final int quantity;
  final int reservedQty;
  final double averageCost;
  final double sellingPrice;

  const VariantItem({
    required this.id,
    required this.sku,
    required this.barcode,
    required this.size,
    required this.colorName,
    required this.colorHex,
    required this.quantity,
    required this.reservedQty,
    required this.averageCost,
    required this.sellingPrice,
  });

  int get availableQty => quantity - reservedQty;
}

class TransactionItem {
  final String id;
  final String type; // 'IN', 'OUT', 'ADJUSTMENT'
  final String reason;
  final int quantity;
  final int balanceAfter;
  final String reference;
  final String sku;
  final DateTime timestamp;

  const TransactionItem({
    required this.id,
    required this.type,
    required this.reason,
    required this.quantity,
    required this.balanceAfter,
    required this.reference,
    required this.sku,
    required this.timestamp,
  });
}

class OrderItemSummary {
  final String id;
  final String orderNumber;
  final String customerName;
  final String customerCode;
  final String status; // 'DRAFT', 'CONFIRMED', 'DISPATCHED'
  final double totalAmount;
  final int itemCount;
  final DateTime date;

  const OrderItemSummary({
    required this.id,
    required this.orderNumber,
    required this.customerName,
    required this.customerCode,
    required this.status,
    required this.totalAmount,
    required this.itemCount,
    required this.date,
  });
}

class KpiMetrics {
  final double inventoryValue;
  final double openPoValue;
  final int lowStockCount;
  final double deadStockValue;
  final int activeProducts;

  const KpiMetrics({
    required this.inventoryValue,
    required this.openPoValue,
    required this.lowStockCount,
    required this.deadStockValue,
    required this.activeProducts,
  });
}
