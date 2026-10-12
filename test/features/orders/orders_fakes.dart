import 'package:scaleezy/features/orders/data/order_models.dart';
import 'package:scaleezy/features/orders/data/order_repository.dart';

import '../products/products_fakes.dart' show offlineClient;

OrderItemSummary order(
  String id, {
  String customer = 'Priya',
  String status = 'CONFIRMED',
  double total = 100,
  int pieces = 1,
  DateTime? date,
  bool atCounter = false,
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
});

OrderDetail orderDetail(String id) => OrderDetail.fromJson({
  'id': id,
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

/// Records each search sent and answers with [answer] / [detail].
class FakeOrderRepository extends OrderRepository {
  FakeOrderRepository({this.answer, this.detail}) : super(offlineClient());

  Future<List<OrderItemSummary>> Function()? answer;
  Future<OrderDetail> Function(String id)? detail;
  final searches = <String?>[];

  @override
  Future<List<OrderItemSummary>> getOrders({String? status, String? search}) {
    searches.add(search);
    return answer!();
  }

  @override
  Future<OrderDetail> getOrder(String id) => detail!(id);
}
