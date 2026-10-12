import 'dart:math';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/network/api_endpoints.dart';
import 'package:scaleezy/core/utils/json_parse.dart';
import 'package:scaleezy/features/purchase_orders/data/purchase_order_models.dart';

/// Purchase orders and receiving deliveries. Permissions noted per call.
class PurchaseOrderRepository {
  PurchaseOrderRepository([ApiClient? client])
    : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  /// purchase_order:view
  Future<List<PurchaseOrderSummary>> purchaseOrders() async => asMaps(
    dataOf(await _api.get(ApiEndpoints.purchaseOrders)),
  ).map(PurchaseOrderSummary.fromJson).toList();

  /// purchase_order:view
  Future<PurchaseOrderDetail> purchaseOrder(String id) async =>
      PurchaseOrderDetail.fromJson(
        asMap(dataOf(await _api.get(ApiEndpoints.purchaseOrder(id)))),
      );

  /// purchase_order:receive. Adds the received pieces to stock. [requestKey] makes a retried
  /// submit (a timeout on a slow line) count once instead of twice.
  Future<void> receivePurchaseOrder(
    String id, {
    required Map<String, int> quantities, // poItemId -> pieces
    required String receivedByName,
    String? supplierReference,
    String? notes,
    required String requestKey,
  }) => _api.post(
    ApiEndpoints.receivePurchaseOrder(id),
    body: {
      'receipts': [
        for (final e in quantities.entries)
          if (e.value > 0) {'poItemId': e.key, 'quantityReceived': e.value},
      ],
      'receivedByName': receivedByName.trim(),
      if (supplierReference != null && supplierReference.trim().isNotEmpty)
        'supplierReference': supplierReference.trim(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      'requestKey': requestKey,
    },
  );

  static String newRequestKey() {
    final r = Random.secure();
    return List.generate(24, (_) => r.nextInt(36).toRadixString(36)).join();
  }
}
