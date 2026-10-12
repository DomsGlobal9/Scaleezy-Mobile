import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/network/api_endpoints.dart';
import 'package:scaleezy/core/utils/json_parse.dart';
import 'package:scaleezy/features/products/data/product_models.dart';
import 'package:scaleezy/features/inventory/data/inventory_models.dart';

/// Stock levels, movements and stock in / out. Permissions noted per call.
class InventoryRepository {
  InventoryRepository([ApiClient? client])
    : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  /// inventory:view. Variants that are tracked, not sold out, and at or under their reorder
  /// level -- the same rule behind the dashboard's criticalStockItems.
  Future<List<VariantItem>> getLowStockVariants({int limit = 5}) async {
    final data = asMap(
      dataOf(
        await _api.get(
          ApiEndpoints.inventoryVariants,
          query: {
            'lowStock': 'true',
            'sortBy': 'quantity',
            'order': 'asc',
            'limit': limit,
          },
        ),
      ),
    );
    return asMaps(data['items']).map(VariantItem.fromInventoryJson).toList();
  }

  /// inventory:view. Newest first; no date filter exists, so callers bucket what comes back.
  /// Answers `{success, data: {data: [...], pagination}}`.
  Future<List<TransactionItem>> getTransactions({
    String? variantId,
    int limit = 50,
  }) async {
    final body = asMap(
      dataOf(
        await _api.get(
          ApiEndpoints.inventoryTransactions,
          query: {'variantId': variantId, 'limit': limit},
        ),
      ),
    );
    return asMaps(body['data']).map(TransactionItem.fromJson).toList();
  }

  /// inventory:receive
  Future<void> stockIn({
    required String variantId,
    required int quantity,
    required String reason,
    double? unitCost,
    String? notes,
  }) => _api.post(
    ApiEndpoints.stockIn,
    body: {
      'variantId': variantId,
      'quantity': quantity,
      'reason': reason,
      'unitCost': ?unitCost,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    },
  );

  /// inventory:adjust. Only DAMAGE, SAMPLE and RETURN_TO_VENDOR are accepted by hand --
  /// sales take stock off by themselves.
  Future<void> stockOut({
    required String variantId,
    required int quantity,
    required String reason,
    String? notes,
  }) => _api.post(
    ApiEndpoints.stockOut,
    body: {
      'variantId': variantId,
      'quantity': quantity,
      'reason': reason,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    },
  );
}
