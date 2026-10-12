import 'package:dio/dio.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/shop/shop_models.dart';
import 'package:scaleezy/features/picking/data/picking_models.dart';
import 'package:scaleezy/features/picking/data/picking_repository.dart';

/// A client that is never called: the fakes below answer instead.
ApiClient offlineClient() => ApiClient.withDio(Dio());

StockLocation store(String id, {String type = 'STORE'}) => StockLocation(
  id: id,
  code: id,
  name: 'Store $id',
  type: type,
  active: true,
);

PickOrder order(String id, {int pieces = 2, String status = 'CONFIRMED'}) =>
    PickOrder(
      id: id,
      orderNumber: 'SO-$id',
      channel: 'POS',
      status: status,
      createdAt: DateTime(2026, 10, 10),
      customer: 'Asha',
      lines: 1,
      pieces: pieces,
    );

Pick pick(String orderId, String lineId, int quantity, {String v = 'v1'}) =>
    Pick(
      orderId: orderId,
      orderNumber: 'SO-$orderId',
      salesOrderItemId: lineId,
      quantity: quantity,
      item: PickItem(
        variantId: v,
        title: 'Saree $v',
        sku: 'SKU-$v',
        barcode: '890$v',
        colorName: 'Red',
      ),
    );

PickStop stop(String spotId, List<Pick> picks, {String? label}) => PickStop(
  spotId: spotId,
  address: spotId.toUpperCase(),
  labelCode: label,
  picks: picks,
);

PickList listOf(
  List<PickStop> stops, {
  List<Pick> notShelved = const [],
  List<Pick> short = const [],
  Map<String, String> orders = const {'o1': 'SO-o1'},
}) => PickList(
  orders: orders,
  stops: stops,
  notShelved: notShelved,
  short: short,
  pieces: [
    ...stops.expand((s) => s.picks),
    ...notShelved,
  ].fold(0, (a, p) => a + p.quantity),
);

/// Answers each call with the matching function and records what was asked, in order.
class FakePickingRepository extends PickingRepository {
  FakePickingRepository({this.orders, this.list, this.notFound, this.send})
    : super(offlineClient());

  Future<List<PickOrder>> Function(String locationId)? orders;
  Future<PickList> Function(List<String> orderIds)? list;
  Future<void> Function()? notFound;
  Future<void> Function(String orderId)? send;

  final calls = <String>[];

  /// Each dispatch body as the server would receive it.
  final dispatched = <Map<String, Object?>>[];

  @override
  Future<List<PickOrder>> pickOrders(String locationId) {
    calls.add('orders $locationId');
    return orders!(locationId);
  }

  @override
  Future<PickList> pickList(String locationId, List<String> orderIds) {
    calls.add('list $locationId ${orderIds.join(',')}');
    return list!(orderIds);
  }

  @override
  Future<void> reportNotFound({
    required String spotId,
    required String variantId,
    required int missing,
  }) {
    calls.add('notFound $spotId $variantId $missing');
    return notFound!();
  }

  @override
  Future<void> dispatch(String salesOrderId, List<DispatchLine> lines) {
    calls.add('dispatch $salesOrderId');
    dispatched.add({
      'salesOrderId': salesOrderId,
      'items': [for (final l in lines) l.toJson()],
    });
    return send!(salesOrderId);
  }
}

/// Signed in with exactly [permissions].
class FakeSession extends AuthSession {
  FakeSession(this.permissions) : super(offlineClient());

  final Set<String> permissions;

  @override
  bool can(String permission) => permissions.contains(permission);
}
