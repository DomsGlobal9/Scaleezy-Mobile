import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/network/api_endpoints.dart';
import 'package:scaleezy/core/utils/json_parse.dart';
import 'package:scaleezy/features/picking/data/picking_models.dart';

/// Pick lists: collecting confirmed orders from the shelves, then sending them out.
/// Permissions noted per call.
class PickingRepository {
  PickingRepository([ApiClient? client]) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  /// shelf:putaway. Orders at [locationId] with pieces still to send, oldest first.
  Future<List<PickOrder>> pickOrders(String locationId) async {
    final data = asMap(
      dataOf(
        await _api.get(
          ApiEndpoints.pickOrders,
          query: {'locationId': locationId},
        ),
      ),
    );
    return asMaps(data['orders']).map(PickOrder.fromJson).toList();
  }

  /// shelf:putaway. One walk for [orderIds] (at most 30), shelves in walking order.
  Future<PickList> pickList(String locationId, List<String> orderIds) async =>
      PickList.fromJson(
        asMap(
          dataOf(
            await _api.get(
              ApiEndpoints.pickList,
              query: {'locationId': locationId, 'orderIds': orderIds.join(',')},
            ),
          ),
        ),
      );

  /// shelf:putaway. [missing] pieces were not on [spotId]. Raises a shelf issue; stock is
  /// not changed.
  Future<void> reportNotFound({
    required String spotId,
    required String variantId,
    required int missing,
  }) => _api.post(
    ApiEndpoints.reportNotFound,
    body: {'spotId': spotId, 'variantId': variantId, 'missing': missing},
  );

  /// dispatch:create. Sends [lines] of one order out. Not idempotent: each call is a new
  /// dispatch, so callers must not repeat it.
  Future<void> dispatch(String salesOrderId, List<DispatchLine> lines) =>
      _api.post(
        ApiEndpoints.dispatches,
        body: {
          'salesOrderId': salesOrderId,
          'items': [for (final l in lines) l.toJson()],
        },
      );
}
