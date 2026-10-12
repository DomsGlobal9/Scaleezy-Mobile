import 'package:scaleezy/core/utils/json_parse.dart';

/// One item's stock at one store: a row of `GET /inventory/variants?locationId=`. The server
/// builds this row by hand, so numbers arrive as numbers; its cost fields (gone without
/// `cost:view`) are not read here.
class StoreStock {
  final String variantId;
  final String title;
  final String sku;

  /// Pieces at that store, counting any held for orders -- the server refuses to move those.
  final int quantity;

  const StoreStock({
    required this.variantId,
    required this.title,
    required this.sku,
    required this.quantity,
  });

  factory StoreStock.fromJson(Map<String, dynamic> j) => StoreStock(
    variantId: asString(j['variantId']),
    title: asOptString(j['productTitle']) ?? asString(j['sku']),
    sku: asString(j['sku']),
    quantity: asInt(j['quantity']),
  );
}
