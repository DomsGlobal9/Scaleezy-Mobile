import 'package:scaleezy/core/utils/json_parse.dart';

/// One stock count (audit) of a store, as listed and as answered by start, complete and cancel.
class StockCount {
  final String id;
  final String name;
  final String status; // DRAFT, IN_PROGRESS, COMPLETED, CANCELLED
  final String? locationId;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? createdBy;

  /// Who finished it, or for a cancelled count who cancelled it.
  final String? completedBy;

  /// How many lines it holds.
  final int itemCount;

  /// Set when the count is completed.
  final int? matchedItems;
  final int? adjustedItems;

  /// Percent of counted lines that matched; null until completed, or when nothing was counted.
  final double? accuracy;

  const StockCount({
    required this.id,
    required this.name,
    required this.status,
    this.locationId,
    required this.createdAt,
    this.completedAt,
    this.createdBy,
    this.completedBy,
    required this.itemCount,
    this.matchedItems,
    this.adjustedItems,
    this.accuracy,
  });

  bool get isOpen => status == 'DRAFT' || status == 'IN_PROGRESS';

  /// Lines with a number entered; only known once completed.
  int? get countedItems => matchedItems == null || adjustedItems == null
      ? null
      : matchedItems! + adjustedItems!;

  factory StockCount.fromJson(Map<String, dynamic> j) => StockCount(
    id: asString(j['id']),
    name: asString(j['name']),
    status: asString(j['status']),
    locationId: asOptString(j['locationId']),
    createdAt: asDateOrNow(j['createdAt']),
    completedAt: asDate(j['completedAt']),
    createdBy: asOptString(j['createdBy']),
    completedBy: asOptString(j['completedBy']),
    // totalItems is kept when it closes; the list carries _count; the detail carries items.
    itemCount: j['totalItems'] != null
        ? asInt(j['totalItems'])
        : j['_count'] != null
        ? asInt(asMap(j['_count'])['items'])
        : asMaps(j['items']).length,
    matchedItems: j['matchedItems'] == null ? null : asInt(j['matchedItems']),
    adjustedItems: j['adjustedItems'] == null
        ? null
        : asInt(j['adjustedItems']),
    accuracy: asMoney(j['accuracy']), // Prisma Decimal, a string
  );
}

/// One variant on a count: what the books said, and what was counted (null = not counted yet).
class StockCountItem {
  final String id;
  final String variantId;
  final String title;
  final String sku;
  final String variantCode;
  final String? barcode;
  final int expected;
  final int? counted;

  /// Stock at the count's store right now; differs from [expected] when it moved since.
  final int onHand;

  StockCountItem({
    required this.id,
    required this.variantId,
    required this.title,
    required this.sku,
    required this.variantCode,
    this.barcode,
    required this.expected,
    this.counted,
    required this.onHand,
  });

  int? get difference => counted == null ? null : counted! - expected;

  /// Lower-cased once, so searching thousands of lines stays cheap.
  late final String searchText = '$title $sku $variantCode ${barcode ?? ''}'
      .toLowerCase();

  /// A scanned or typed code: barcode, SKU or variant code, ignoring case.
  bool matchesCode(String code) {
    final c = code.toLowerCase();
    return barcode?.toLowerCase() == c ||
        sku.toLowerCase() == c ||
        variantCode.toLowerCase() == c;
  }

  /// After a save: the server also resets [expected] to the stock at the moment of counting.
  StockCountItem withCount({
    required int expected,
    required int? counted,
  }) => StockCountItem(
    id: id,
    variantId: variantId,
    title: title,
    sku: sku,
    variantCode: variantCode,
    barcode: barcode,
    expected: expected,
    counted: counted,
    // A counted line's expected figure is the stock as the server read it just now.
    onHand: counted != null ? expected : onHand,
  );

  factory StockCountItem.fromJson(Map<String, dynamic> j) {
    final variant = asMap(j['variant']);
    return StockCountItem(
      id: asString(j['id']),
      variantId: asString(j['variantId']),
      title: asOptString(asMap(variant['product'])['title']) ?? 'Product',
      sku: asString(j['sku']),
      variantCode: asString(j['variantCode']),
      barcode: asOptString(j['barcode']),
      expected: asInt(j['expectedQty']),
      counted: j['countedQty'] == null ? null : asInt(j['countedQty']),
      onHand: variant.containsKey('quantity')
          ? asInt(variant['quantity'])
          : asInt(j['expectedQty']),
    );
  }
}

/// A count with every line, sorted by product then SKU so the order is stable between loads.
class StockCountDetail {
  final StockCount count;
  final List<StockCountItem> items;

  const StockCountDetail(this.count, this.items);

  factory StockCountDetail.fromJson(Map<String, dynamic> j) => StockCountDetail(
    StockCount.fromJson(j),
    asMaps(j['items']).map(StockCountItem.fromJson).toList()..sort((a, b) {
      final t = a.title.toLowerCase().compareTo(b.title.toLowerCase());
      return t != 0 ? t : a.sku.compareTo(b.sku);
    }),
  );
}
