import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/network/api_endpoints.dart';
import 'package:scaleezy/core/utils/json_parse.dart';
import 'package:scaleezy/features/orders/data/order_models.dart';
import 'package:scaleezy/features/orders/data/receipt_models.dart';

/// Sales orders. Permissions noted per call.
class OrderRepository {
  OrderRepository([ApiClient? client]) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  /// sales_order:view. This route answers a bare array, not `{success, data}`.
  Future<List<OrderItemSummary>> getOrders({
    String? status,
    String? search,
  }) async => asMaps(
    dataOf(
      await _api.get(
        ApiEndpoints.salesOrders,
        query: {'status': status, 'search': search},
      ),
    ),
  ).map(OrderItemSummary.fromJson).toList();

  /// sales_order:view. Also a bare object.
  Future<OrderDetail> getOrder(String id) async => OrderDetail.fromJson(
    asMap(dataOf(await _api.get(ApiEndpoints.salesOrder(id)))),
  );

  /// sales_order:view. Answers for any of the shop's orders; only counter bills are receipts.
  Future<Receipt> getReceipt(String orderId) async => Receipt.fromJson(
    asMap(dataOf(await _api.get(ApiEndpoints.receipt(orderId)))),
  );
}
