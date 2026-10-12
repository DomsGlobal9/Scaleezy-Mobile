import 'package:dio/dio.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/features/purchase_orders/data/purchase_order_models.dart';
import 'package:scaleezy/features/purchase_orders/data/purchase_order_repository.dart';

/// A client that is never called: the fakes below answer instead.
ApiClient offlineClient() => ApiClient.withDio(Dio());

PurchaseOrderSummary summary(
  String id, {
  required String status,
  String supplier = 'Weavers Co',
}) => PurchaseOrderSummary.fromJson({
  'id': id,
  'poNumber': 'PO-$id',
  'status': status,
  'createdAt': '2026-09-01T00:00:00Z',
  'supplier': {'name': supplier},
  '_count': {'items': 1},
});

PurchaseOrderDetail detail({List<Map<String, Object?>>? items}) =>
    PurchaseOrderDetail.fromJson({
      'id': 'po1',
      'poNumber': 'PO-7',
      'status': 'PARTIALLY_RECEIVED',
      'createdAt': '2026-09-01T00:00:00Z',
      'supplier': {'name': 'Weavers Co'},
      'items':
          items ??
          [
            line('i1', ordered: 10, received: 4),
            line('i2', ordered: 3, received: 0),
            line('i3', ordered: 2, received: 2),
          ],
    });

Map<String, Object?> line(
  String id, {
  required int ordered,
  required int received,
}) => {
  'id': id,
  'variantId': 'v-$id',
  'productTitle': 'Saree $id',
  'sku': 'SKU-$id',
  'barcode': 'BC-$id',
  'orderedQty': ordered,
  'receivedQty': received,
};

/// Answers with the given functions and records each receive.
class FakePurchaseOrderRepository extends PurchaseOrderRepository {
  FakePurchaseOrderRepository({this.list, this.one, this.receive})
    : super(offlineClient());

  Future<List<PurchaseOrderSummary>> Function()? list;
  Future<PurchaseOrderDetail> Function()? one;
  Future<void> Function()? receive;
  final loaded = <String>[];
  final receipts = <Map<String, Object?>>[];

  @override
  Future<List<PurchaseOrderSummary>> purchaseOrders() => list!();

  @override
  Future<PurchaseOrderDetail> purchaseOrder(String id) {
    loaded.add(id);
    return one!();
  }

  @override
  Future<void> receivePurchaseOrder(
    String id, {
    required Map<String, int> quantities,
    required String receivedByName,
    String? supplierReference,
    String? notes,
    required String requestKey,
  }) {
    receipts.add({
      'id': id,
      'quantities': Map.of(quantities),
      'receivedByName': receivedByName,
      'supplierReference': supplierReference,
      'requestKey': requestKey,
    });
    return receive!();
  }
}
