import 'package:scaleezy/core/shop/shop_models.dart';
import 'package:scaleezy/features/transfers/data/transfer_models.dart';
import 'package:scaleezy/features/transfers/data/transfer_repository.dart';

import '../scanner/scanner_fakes.dart';

export '../scanner/scanner_fakes.dart';

StockLocation store(String id, {String type = 'STORE'}) => StockLocation(
  id: id,
  code: id,
  name: 'Store $id',
  type: type,
  active: true,
);

/// A row of GET /inventory/variants as the backend builds it, for a role without cost:view.
Map<String, Object?> stockRow(
  String variantId, {
  String title = 'Saree',
  int quantity = 5,
}) => {
  'variantId': variantId,
  'productId': 'p-$variantId',
  'sku': 'SKU-$variantId',
  'productTitle': title,
  'category': 'WOMEN',
  'quantity': quantity,
  'costBasis': 'AVERAGE',
  'costIsEstimate': false,
  'status': 'ACTIVE',
  'inventoryStatus': quantity > 0 ? 'HEALTHY' : 'OUT_OF_STOCK',
  'reorderLevel': 2,
  'lowStockThreshold': 2,
  'updatedAt': '2026-10-01T10:00:00.000Z',
};

StoreStock stock(
  String variantId, {
  String title = 'Saree',
  int quantity = 5,
}) =>
    StoreStock.fromJson(stockRow(variantId, title: title, quantity: quantity));

/// Answers with the given functions and records every call.
class FakeTransferRepository extends TransferRepository {
  FakeTransferRepository({this.stock, this.send}) : super(offlineClient());

  Future<List<StoreStock>> Function(String locationId, String search)? stock;
  Future<void> Function()? send;
  final searches = <String>[];
  final sent = <Map<String, Object?>>[];

  @override
  Future<List<StoreStock>> stockAt(
    String locationId, {
    required String search,
    int limit = 20,
  }) {
    searches.add('$locationId $search');
    return stock!(locationId, search);
  }

  @override
  Future<void> transfer({
    required String fromId,
    required String toId,
    required Map<String, int> quantities,
    String? notes,
  }) {
    sent.add({
      'from': fromId,
      'to': toId,
      'quantities': Map.of(quantities),
      'notes': notes,
    });
    return send!();
  }
}
