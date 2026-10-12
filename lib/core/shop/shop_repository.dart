import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/network/api_endpoints.dart';
import 'package:scaleezy/core/utils/json_parse.dart';
import 'package:scaleezy/core/shop/shop_models.dart';

/// The shop around the signed-in person: branding and stores. Permissions noted per call.
class ShopRepository {
  ShopRepository([ApiClient? client]) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  /// Any signed-in user. Name and logo the owner set for the shop; all fields may be null.
  Future<Branding> getBranding() async =>
      Branding.fromJson(asMap(dataOf(await _api.get(ApiEndpoints.branding))));

  /// dashboard:view. A bare array.
  Future<List<StockLocation>> getLocations() async => asMaps(
    dataOf(await _api.get(ApiEndpoints.locations)),
  ).map(StockLocation.fromJson).toList();

  /// Account owner only.
  Future<Branding> updateShopDetails({
    String? businessAddress,
    String? businessPhone,
  }) async => Branding.fromJson(
    asMap(
      dataOf(
        await _api.put(
          ApiEndpoints.brandingDetails,
          body: {
            'businessAddress': businessAddress,
            'businessPhone': businessPhone,
          },
        ),
      ),
    ),
  );

  /// Account owner only.
  Future<Branding> updateShopName(String? name) async => Branding.fromJson(
    asMap(
      dataOf(
        await _api.put(ApiEndpoints.brandingName, body: {'businessName': name}),
      ),
    ),
  );
}
