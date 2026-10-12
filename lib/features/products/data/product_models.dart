import 'package:scaleezy/core/utils/json_parse.dart';

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
    final colours = asMaps(
      j['colours'],
    ).map(VariantItem.fromColourJson).toList();
    return ProductItem(
      id: asString(j['id']),
      title: asString(j['title']),
      productCode: asString(j['productCode']),
      category: asString(j['category']),
      productType: asString(j['productType']),
      fabric: asOptString(j['fabric']) ?? asOptString(j['dressType']) ?? '',
      basePrice: asMoney(j['basePrice']) ?? 0,
      totalUnits: asInt(summary['totalUnits']),
      variantCount: summary.containsKey('variantCount')
          ? asInt(summary['variantCount'])
          : colours.length,
      lowStockVariants: asInt(summary['lowStockVariants']),
      status: asString(j['status']),
      coverImageUrl: asOptString(j['coverImageUrl']),
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

  /// "You pay": the cost typed in by hand. Null when not set, or when the role lacks
  /// `cost:view` (the server strips it).
  final double? costPrice;

  /// Average cost of the stock received. Null without `cost:view`; 0 when never costed.
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
    this.costPrice,
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

  /// The average, worth showing as "Average cost" only when it is known and differs from
  /// "You pay".
  double? get averageCostIfDifferent =>
      (averageCost ?? 0) > 0 && averageCost != costPrice ? averageCost : null;

  String get label => [
    if (colorName.isNotEmpty) colorName,
    if (size.isNotEmpty) 'Size $size',
  ].join(' • ');

  /// GET /products/:productId/variants
  factory VariantItem.fromJson(Map<String, dynamic> j) {
    final stocks = asMaps(j['stocks']);
    final product = j['product'] is Map
        ? Map<String, dynamic>.from(j['product'])
        : const {};
    return VariantItem(
      id: asString(j['id']),
      productTitle: asString(product['title']),
      sku: asString(j['sku']),
      barcode: asString(j['barcode']),
      size: asString(j['size']),
      colorName: asString(j['colorName']),
      colorHex: asHexColor(j['hexCode']),
      quantity: j.containsKey('totalQuantity')
          ? asInt(j['totalQuantity'])
          : stocks.fold(0, (sum, s) => sum + asInt(s['quantity'])),
      reservedQty: stocks.fold(0, (sum, s) => sum + asInt(s['reservedQty'])),
      reorderLevel: asInt(j['reorderLevel']),
      costPrice: _setCost(j['costPrice']),
      averageCost: asMoney(j['averageCost']),
      sellingPrice: asMoney(j['sellingPrice']) ?? asMoney(product['basePrice']),
      photoUrl: asOptString(j['photoUrl']),
      stockByLocation: asMaps(
        j['stockByLocation'],
      ).map(LocationStock.fromJson).toList(),
    );
  }

  /// GET /variants/search -> data.items[]
  factory VariantItem.fromSearchJson(Map<String, dynamic> j) => VariantItem(
    id: asString(j['id']),
    productTitle: asString(j['productTitle']),
    sku: asString(j['sku']),
    barcode: asString(j['barcode']),
    size: asString(j['size']),
    colorName: asString(j['color']),
    quantity: asInt(j['stock']),
    reorderLevel: asInt(j['reorderLevel']),
    costPrice: _setCost(j['costPrice']),
    averageCost: asMoney(j['averageCost']),
    sellingPrice:
        asMoney(j['effectiveSellingPrice']) ?? asMoney(j['sellingPrice']),
  );

  /// GET /inventory/variants -> data.items[]
  factory VariantItem.fromInventoryJson(Map<String, dynamic> j) => VariantItem(
    id: asString(j['variantId']),
    productTitle: asString(j['productTitle']),
    sku: asString(j['sku']),
    barcode: '',
    size: '',
    colorName: '',
    quantity: asInt(j['quantity']),
    reorderLevel: asInt(j['reorderLevel']),
    averageCost: asMoney(j['averageCost']),
  );

  /// GET /products -> data[].colours[]
  factory VariantItem.fromColourJson(Map<String, dynamic> j) => VariantItem(
    id: asString(j['id']),
    sku: asString(j['variantCode']),
    barcode: '',
    size: asString(j['size']),
    colorName: asString(j['colorName']),
    quantity: asInt(j['units']),
    sellingPrice: asMoney(j['sellingPrice']),
    photoUrl: asOptString(j['photoUrl']),
  );
}

/// A hand-entered cost; /variants/search sends 0 for "not set", like the website's `v.costPrice ?`.
double? _setCost(dynamic v) {
  final cost = asMoney(v);
  return cost != null && cost > 0 ? cost : null;
}

/// One hit from GET /search: a variant (barcode, SKU or variant code) or a product (code).
class SearchHit {
  final String id;
  final String label;
  final String code;
  final String sku;
  final String barcode;

  const SearchHit({
    required this.id,
    required this.label,
    required this.code,
    this.sku = '',
    this.barcode = '',
  });

  factory SearchHit.fromJson(Map<String, dynamic> j) => SearchHit(
    id: asString(j['id']),
    label: asString(j['label']),
    code: asString(j['code']),
    sku: asString(j['sku']),
    barcode: asString(j['barcode']),
  );

  /// The identifier that equals [q], ignoring case, as the server spells it; null for a
  /// fuzzy (title or colour) hit.
  String? exactCode(String q) {
    final want = q.trim().toLowerCase();
    for (final c in [barcode, sku, code]) {
      if (c.isNotEmpty && c.toLowerCase() == want) return c;
    }
    return null;
  }
}

/// GET /search -> data. Exact identifier matches come back alone; otherwise title matches.
class SearchResults {
  final List<SearchHit> products;
  final List<SearchHit> variants;

  const SearchResults({this.products = const [], this.variants = const []});

  factory SearchResults.fromJson(Map<String, dynamic> j) => SearchResults(
    products: asMaps(j['products']).map(SearchHit.fromJson).toList(),
    variants: asMaps(j['variants']).map(SearchHit.fromJson).toList(),
  );
}

/// A choice from GET /catalog/config, e.g. category WOMEN labelled "Women".
typedef CatalogOption = ({String value, String label});

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
    locationId: asString(j['locationId']),
    name: asString(j['name']),
    quantity: asInt(j['quantity']),
  );
}
