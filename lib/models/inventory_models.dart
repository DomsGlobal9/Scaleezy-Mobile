// Shapes read from inventory_backend (main). Prisma Decimal fields serialise as strings
// ("2123.50"), plain numbers as numbers, so money is parsed from either.

double? _money(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

int _int(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

String _str(dynamic v) => v is String ? v : (v?.toString() ?? '');

String? _optStr(dynamic v) => v is String && v.trim().isNotEmpty ? v : null;

DateTime _date(dynamic v) =>
    (v is String ? DateTime.tryParse(v)?.toLocal() : null) ?? DateTime.now();

List<Map<String, dynamic>> _maps(dynamic v) => v is List
    ? v.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
    : const [];

/// "#B91C1C" / "B91C1C" -> 0xFFB91C1C.
int? _hex(dynamic v) {
  final s = _optStr(v)?.replaceFirst('#', '');
  if (s == null || s.length != 6) return null;
  final n = int.tryParse(s, radix: 16);
  return n == null ? null : 0xFF000000 | n;
}

class AuthUser {
  final String id;
  final String clientId;
  final String name;
  final String email;
  final List<String> roles;
  final Set<String> permissions;

  const AuthUser({
    required this.id,
    required this.clientId,
    required this.name,
    required this.email,
    required this.roles,
    required this.permissions,
  });

  /// The server has already expanded implied permissions; the owner holds `*`.
  bool can(String permission) =>
      permissions.contains('*') || permissions.contains(permission);

  /// The account owner -- the only one who may change the shop's name and details.
  bool get isOwner => permissions.contains('*');

  /// [clientId] is passed separately for /auth/session, which carries it as `client.id`.
  factory AuthUser.fromJson(Map<String, dynamic> j, {String? clientId}) =>
      AuthUser(
        id: _str(j['id']),
        clientId: _optStr(j['clientId']) ?? clientId ?? '',
        name: _optStr(j['name']) ?? _str(j['email']),
        email: _str(j['email']),
        roles: (j['roles'] as List? ?? const []).map(_str).toList(),
        permissions: (j['permissions'] as List? ?? const []).map(_str).toSet(),
      );
}

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
  final int lowStockVariants;
  final String status;
  final String? coverImageUrl;

  /// From the list endpoint these are the lightweight "colours" (no sku/barcode/cost);
  /// the full rows come from [ApiRepository.getProductVariants].
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
    required this.lowStockVariants,
    required this.status,
    this.coverImageUrl,
    this.variants = const [],
  });

  factory ProductItem.fromJson(Map<String, dynamic> j) {
    final summary = j['variantSummary'] is Map
        ? Map<String, dynamic>.from(j['variantSummary'])
        : const {};
    final colours = _maps(
      j['colours'],
    ).map(VariantItem.fromColourJson).toList();
    return ProductItem(
      id: _str(j['id']),
      title: _str(j['title']),
      productCode: _str(j['productCode']),
      category: _str(j['category']),
      productType: _str(j['productType']),
      fabric: _optStr(j['fabric']) ?? _optStr(j['dressType']) ?? '',
      basePrice: _money(j['basePrice']) ?? 0,
      totalUnits: _int(summary['totalUnits']),
      variantCount: summary.containsKey('variantCount')
          ? _int(summary['variantCount'])
          : colours.length,
      lowStockVariants: _int(summary['lowStockVariants']),
      status: _str(j['status']),
      coverImageUrl: _optStr(j['coverImageUrl']),
      variants: colours,
    );
  }
}

class VariantItem {
  final String id;
  final String productTitle;
  final String sku;
  final String barcode;
  final String size;
  final String colorName;
  final int? colorHex;
  final int quantity;
  final int reservedQty;
  final int reorderLevel;

  /// Null when the signed-in role lacks `cost:view` -- the server strips it.
  final double? averageCost;
  final double? sellingPrice;
  final String? photoUrl;
  final List<LocationStock> stockByLocation;

  const VariantItem({
    required this.id,
    this.productTitle = '',
    required this.sku,
    required this.barcode,
    required this.size,
    required this.colorName,
    this.colorHex,
    required this.quantity,
    this.reservedQty = 0,
    this.reorderLevel = 0,
    this.averageCost,
    this.sellingPrice,
    this.photoUrl,
    this.stockByLocation = const [],
  });

  int get availableQty => quantity - reservedQty;

  /// Same rule as the server's isLowStock: tracked, something left, and at or under the level.
  bool get isLowStock =>
      reorderLevel > 0 && quantity > 0 && quantity <= reorderLevel;
  bool get isOutOfStock => quantity <= 0;

  String get label => [
    if (colorName.isNotEmpty) colorName,
    if (size.isNotEmpty) 'Size $size',
  ].join(' • ');

  /// GET /products/:productId/variants
  factory VariantItem.fromJson(Map<String, dynamic> j) {
    final stocks = _maps(j['stocks']);
    final product = j['product'] is Map
        ? Map<String, dynamic>.from(j['product'])
        : const {};
    return VariantItem(
      id: _str(j['id']),
      productTitle: _str(product['title']),
      sku: _str(j['sku']),
      barcode: _str(j['barcode']),
      size: _str(j['size']),
      colorName: _str(j['colorName']),
      colorHex: _hex(j['hexCode']),
      quantity: j.containsKey('totalQuantity')
          ? _int(j['totalQuantity'])
          : stocks.fold(0, (sum, s) => sum + _int(s['quantity'])),
      reservedQty: stocks.fold(0, (sum, s) => sum + _int(s['reservedQty'])),
      reorderLevel: _int(j['reorderLevel']),
      averageCost: _money(j['averageCost']),
      sellingPrice: _money(j['sellingPrice']) ?? _money(product['basePrice']),
      photoUrl: _optStr(j['photoUrl']),
      stockByLocation: _maps(
        j['stockByLocation'],
      ).map(LocationStock.fromJson).toList(),
    );
  }

  /// GET /variants/search -> data.items[]
  factory VariantItem.fromSearchJson(Map<String, dynamic> j) => VariantItem(
    id: _str(j['id']),
    productTitle: _str(j['productTitle']),
    sku: _str(j['sku']),
    barcode: _str(j['barcode']),
    size: _str(j['size']),
    colorName: _str(j['color']),
    quantity: _int(j['stock']),
    reorderLevel: _int(j['reorderLevel']),
    averageCost: _money(j['averageCost']),
    sellingPrice:
        _money(j['effectiveSellingPrice']) ?? _money(j['sellingPrice']),
  );

  /// GET /inventory/variants -> data.items[]
  factory VariantItem.fromInventoryJson(Map<String, dynamic> j) => VariantItem(
    id: _str(j['variantId']),
    productTitle: _str(j['productTitle']),
    sku: _str(j['sku']),
    barcode: '',
    size: '',
    colorName: '',
    quantity: _int(j['quantity']),
    reorderLevel: _int(j['reorderLevel']),
    averageCost: _money(j['averageCost']),
  );

  /// GET /products -> data[].colours[]
  factory VariantItem.fromColourJson(Map<String, dynamic> j) => VariantItem(
    id: _str(j['id']),
    sku: _str(j['variantCode']),
    barcode: '',
    size: _str(j['size']),
    colorName: _str(j['colorName']),
    quantity: _int(j['units']),
    sellingPrice: _money(j['sellingPrice']),
    photoUrl: _optStr(j['photoUrl']),
  );
}

class TransactionItem {
  final String id;
  final String type; // IN, OUT, ADJUSTMENT
  final String reason;
  final int quantity;
  final int balanceAfter;
  final String reference;
  final String sku;
  final String productTitle;
  final String performedBy;
  final DateTime timestamp;

  const TransactionItem({
    required this.id,
    required this.type,
    required this.reason,
    required this.quantity,
    required this.balanceAfter,
    required this.reference,
    required this.sku,
    required this.productTitle,
    this.performedBy = '',
    required this.timestamp,
  });

  bool get isInbound => quantity > 0;

  factory TransactionItem.fromJson(Map<String, dynamic> j) {
    final variant = j['variant'] is Map
        ? Map<String, dynamic>.from(j['variant'])
        : const {};
    final product = variant['product'] is Map
        ? Map<String, dynamic>.from(variant['product'])
        : const {};
    return TransactionItem(
      id: _str(j['id']),
      type: _str(j['type']),
      reason: _str(j['reason']),
      quantity: _int(j['quantity']),
      balanceAfter: _int(j['balanceAfter']),
      reference: _optStr(j['referenceType']) ?? _optStr(j['notes']) ?? '',
      sku: _optStr(j['sku']) ?? _str(variant['sku']),
      productTitle: _optStr(j['productTitle']) ?? _str(product['title']),
      performedBy: _str(j['createdBy']),
      timestamp: _date(j['createdAt']),
    );
  }
}

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
    totalProducts: _int(j['totalProducts']),
    activeProducts: _int(j['activeProducts']),
    criticalStockItems: _int(j['criticalStockItems']),
    totalUnits: _int(j['totalUnits']),
    inventoryValue: _money(j['inventoryValue']),
    openPurchaseOrders: _int(j['openPurchaseOrders']),
    pendingReceipts: _int(j['pendingReceipts']),
    totalSuppliers: _int(j['totalSuppliers']),
    recentTransactions: _maps(
      j['recentTransactions'],
    ).map(TransactionItem.fromJson).toList(),
  );
}

class OrderItemSummary {
  final String id;
  final String orderNumber;
  final String customerName;
  final String customerPhone;
  final String
  status; // DRAFT, CONFIRMED, PARTIALLY_DISPATCHED, DISPATCHED, CANCELLED
  final double totalAmount;
  final int itemCount;
  final DateTime date;
  final bool atCounter;

  const OrderItemSummary({
    required this.id,
    required this.orderNumber,
    required this.customerName,
    required this.customerPhone,
    required this.status,
    required this.totalAmount,
    required this.itemCount,
    required this.date,
    this.atCounter = false,
  });

  factory OrderItemSummary.fromJson(Map<String, dynamic> j) {
    final customer = j['customer'] is Map
        ? Map<String, dynamic>.from(j['customer'])
        : const {};
    final items = _maps(j['items']);
    return OrderItemSummary(
      id: _str(j['id']),
      orderNumber: _str(j['orderNumber']),
      customerName:
          _optStr(j['customerName']) ??
          _optStr(customer['name']) ??
          _optStr(customer['companyName']) ??
          'Walk-in customer',
      customerPhone: _optStr(j['customerPhone']) ?? _str(customer['phone']),
      status: _str(j['status']),
      totalAmount: _money(j['total']) ?? 0,
      itemCount: items.fold(0, (sum, i) => sum + _int(i['quantity'])),
      date: _date(j['createdAt']),
      atCounter: j['atCounter'] == true,
    );
  }
}

class OrderLine {
  final String title;
  final String sku;
  final String size;
  final String colorName;
  final int quantity;
  final int fulfilledQty;
  final double unitPrice;
  final double totalPrice;

  const OrderLine({
    required this.title,
    required this.sku,
    required this.size,
    required this.colorName,
    required this.quantity,
    required this.fulfilledQty,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory OrderLine.fromJson(Map<String, dynamic> j) {
    final variant = j['variant'] is Map
        ? Map<String, dynamic>.from(j['variant'])
        : const {};
    final product = variant['product'] is Map
        ? Map<String, dynamic>.from(variant['product'])
        : const {};
    return OrderLine(
      title: _optStr(product['title']) ?? _str(j['productTitle']),
      sku: _optStr(variant['sku']) ?? _str(j['sku']),
      size: _str(variant['size']),
      colorName: _str(variant['colorName']),
      quantity: _int(j['quantity']),
      fulfilledQty: _int(j['fulfilledQty']),
      unitPrice: _money(j['unitPrice']) ?? 0,
      totalPrice: _money(j['totalPrice']) ?? 0,
    );
  }
}

class OrderDetail {
  final OrderItemSummary summary;
  final double subtotal;
  final double discountAmount;
  final double taxAmount;
  final double shippingAmount;
  final List<OrderLine> lines;

  const OrderDetail({
    required this.summary,
    required this.subtotal,
    required this.discountAmount,
    required this.taxAmount,
    required this.shippingAmount,
    required this.lines,
  });

  factory OrderDetail.fromJson(Map<String, dynamic> j) => OrderDetail(
    summary: OrderItemSummary.fromJson(j),
    subtotal: _money(j['subtotal']) ?? 0,
    discountAmount: _money(j['discountAmount']) ?? 0,
    taxAmount: _money(j['taxAmount']) ?? 0,
    shippingAmount: _money(j['shippingAmount']) ?? 0,
    lines: _maps(j['items']).map(OrderLine.fromJson).toList(),
  );
}

class Paged<T> {
  final List<T> items;
  final int page;
  final int pages;
  final int total;

  const Paged({
    required this.items,
    required this.page,
    required this.pages,
    required this.total,
  });

  bool get hasMore => page < pages;
}

class LocationStock {
  final String locationId;
  final String name;
  final int quantity;

  const LocationStock({
    required this.locationId,
    required this.name,
    required this.quantity,
  });

  factory LocationStock.fromJson(Map<String, dynamic> j) => LocationStock(
    locationId: _str(j['locationId']),
    name: _str(j['name']),
    quantity: _int(j['quantity']),
  );
}

class StockLocation {
  final String id;
  final String code;
  final String name;
  final String type; // STORE, ONLINE, WAREHOUSE
  final bool active;

  const StockLocation({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    required this.active,
  });

  factory StockLocation.fromJson(Map<String, dynamic> j) => StockLocation(
    id: _str(j['id']),
    code: _str(j['code']),
    name: _optStr(j['name']) ?? _str(j['code']),
    type: _str(j['type']),
    active: j['active'] != false,
  );
}

class Branding {
  final String? businessName;
  final String? logoUrl;
  final String? businessAddress;
  final String? businessPhone;

  const Branding({
    this.businessName,
    this.logoUrl,
    this.businessAddress,
    this.businessPhone,
  });

  factory Branding.fromJson(Map<String, dynamic> j) => Branding(
    businessName: _optStr(j['businessName']),
    logoUrl: _optStr(j['logoUrl']),
    businessAddress: _optStr(j['businessAddress']),
    businessPhone: _optStr(j['businessPhone']),
  );
}
