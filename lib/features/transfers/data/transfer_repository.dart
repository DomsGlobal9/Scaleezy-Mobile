import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/network/api_endpoints.dart';
import 'package:scaleezy/core/utils/json_parse.dart';
import 'package:scaleezy/features/transfers/data/transfer_models.dart';

/// Moving stock from one store to another. Permissions noted per call.
class TransferRepository {
  TransferRepository([ApiClient? client]) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  /// inventory:view (implied by inventory:transfer). Items at [locationId] whose name, SKU,
  /// variant code or barcode contains [search]; the query's locationId wins over the
  /// x-location-id header. Answers `{success, data: {items, pagination}}`.
  Future<List<StoreStock>> stockAt(
    String locationId, {
    required String search,
    int limit = 20,
  }) async {
    final data = asMap(
      dataOf(
        await _api.get(
          ApiEndpoints.inventoryVariants,
          query: {
            'locationId': locationId,
            'search': search.trim(),
            'limit': limit,
          },
        ),
      ),
    );
    return asMaps(data['items']).map(StoreStock.fromJson).toList();
  }

  /// inventory:transfer. Moves the pieces at once, in one go or not at all: out of [fromId]
  /// (pieces not on a shelf first), into [toId] where they wait to be put away. There is no
  /// request key, so a retry moves them again. Answers `{success, transferredItems}`.
  Future<void> transfer({
    required String fromId,
    required String toId,
    required Map<String, int> quantities, // variantId -> pieces
    String? notes,
  }) => _api.post(
    ApiEndpoints.inventoryTransfers,
    body: {
      'originLocationId': fromId,
      'destinationLocationId': toId,
      'items': [
        for (final e in quantities.entries)
          {'variantId': e.key, 'quantity': e.value},
      ],
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    },
  );
}
