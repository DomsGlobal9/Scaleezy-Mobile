import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/network/api_endpoints.dart';
import 'package:scaleezy/core/utils/json_parse.dart';
import 'package:scaleezy/features/shelves/data/shelf_models.dart';

/// Shelves: where pieces sit inside a store. Permissions noted per call.
class ShelfRepository {
  ShelfRepository([ApiClient? client]) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  /// shelf:view
  Future<ShelfTree> shelfTree(String locationId) async => ShelfTree.fromJson(
    asMap(dataOf(await _api.get(ApiEndpoints.shelfSpots(locationId)))),
  );

  /// shelf:view. [code] is what the shelf label's barcode reads.
  Future<SpotContents> scanSpot(String code, {String? locationId}) async =>
      SpotContents.fromJson(
        asMap(
          dataOf(
            await _api.get(
              ApiEndpoints.scanSpot,
              query: {'code': code.trim(), 'locationId': locationId},
            ),
          ),
        ),
      );

  /// shelf:view
  Future<SpotContents> spot(String spotId) async => SpotContents.fromJson(
    asMap(dataOf(await _api.get(ApiEndpoints.spot(spotId)))),
  );

  /// shelf:view. Where a piece is, searched by name, SKU or barcode.
  Future<List<WhereItem>> findOnShelves(String q, {String? locationId}) async {
    final data = asMap(
      dataOf(
        await _api.get(
          ApiEndpoints.findOnShelves,
          query: {'q': q.trim(), 'locationId': locationId},
        ),
      ),
    );
    return asMaps(data['items']).map(WhereItem.fromJson).toList();
  }

  /// shelf:view
  Future<List<NotShelvedItem>> notShelved(String locationId) async {
    final data = asMap(
      dataOf(await _api.get(ApiEndpoints.notShelved(locationId))),
    );
    return asMaps(data['items']).map(NotShelvedItem.fromJson).toList();
  }

  /// shelf:putaway. Pieces not on any shelf yet go onto [spotId].
  /// Moves pieces between shelves only; the location's stock count does not change.
  Future<String?> putAway({
    required String locationId,
    required String variantId,
    required String spotId,
    required int quantity,
  }) async {
    final body = await _api.post(
      ApiEndpoints.putAway,
      body: {
        'locationId': locationId,
        'variantId': variantId,
        'spotId': spotId,
        'quantity': quantity,
      },
    );
    return asMap(dataOf(body))['warning'] as String?;
  }

  /// shelf:putaway. From one shelf to another (either may be null, not both).
  Future<String?> moveOnShelves({
    required String locationId,
    required String variantId,
    String? fromSpotId,
    String? toSpotId,
    required int quantity,
  }) async {
    final body = await _api.post(
      ApiEndpoints.moveOnShelves,
      body: {
        'locationId': locationId,
        'variantId': variantId,
        'fromSpotId': ?fromSpotId,
        'toSpotId': ?toSpotId,
        'quantity': quantity,
      },
    );
    return asMap(dataOf(body))['warning'] as String?;
  }
}
