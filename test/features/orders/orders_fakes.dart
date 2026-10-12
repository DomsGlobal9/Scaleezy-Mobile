import 'package:scaleezy/features/orders/data/order_models.dart';
import 'package:scaleezy/features/orders/data/order_repository.dart';
import 'package:scaleezy/features/orders/data/receipt_models.dart';

import '../../support/fake_api.dart';

export '../../support/fixtures.dart' show receiptJson;

OrderItemSummary order(
  String id, {
  String customer = 'Priya',
  String status = 'CONFIRMED',
  double total = 100,
  int pieces = 1,
  DateTime? date,
  bool atCounter = false,
  String? sourceSystem,
  Map<String, dynamic>? payment,
}) => OrderItemSummary.fromJson({
  'id': id,
  'orderNumber': 'SO-$id',
  'customerName': customer,
  'status': status,
  'total': total.toStringAsFixed(2),
  'items': [
    {'quantity': pieces},
  ],
  'createdAt': (date ?? DateTime.now()).toIso8601String(),
  'atCounter': atCounter,
  'sourceSystem': sourceSystem,
  'payment': payment,
});

OrderDetail orderDetail(String id, {bool atCounter = false}) =>
    OrderDetail.fromJson({
      'id': id,
      'atCounter': atCounter,
      'orderNumber': 'SO-$id',
      'customerName': 'Priya',
      'status': 'CONFIRMED',
      'total': '2998.00',
      'subtotal': '2998.00',
      'createdAt': DateTime.now().toIso8601String(),
      'items': [
        {
          'quantity': 2,
          'unitPrice': '1499.00',
          'totalPrice': '2998.00',
          'variant': {
            'sku': 'SKU-1',
            'size': 'M',
            'colorName': 'Red',
            'product': {'title': 'Banarasi Saree'},
          },
        },
      ],
    });

/// Records each search and "where from" sent and answers with [answer] / [detail] / [receipt].
class FakeOrderRepository extends OrderRepository {
  FakeOrderRepository({this.answer, this.detail, this.receipt})
    : super(offlineClient());

  Future<List<OrderItemSummary>> Function()? answer;
  Future<OrderDetail> Function(String id)? detail;
  Future<Receipt> Function(String id)? receipt;
  final searches = <String?>[];
  final sources = <String?>[];

  @override
  Future<List<OrderItemSummary>> getOrders({
    String? status,
    String? search,
    String? source,
  }) {
    searches.add(search);
    sources.add(source);
    return answer!();
  }

  @override
  Future<OrderDetail> getOrder(String id) => detail!(id);

  @override
  Future<Receipt> getReceipt(String orderId) => receipt!(orderId);
}
