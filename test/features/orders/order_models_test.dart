import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/features/orders/data/order_models.dart';

void main() {
  test('orders list: raw array item', () {
    final o = OrderItemSummary.fromJson({
      'id': 'o1',
      'orderNumber': 'SO-0001',
      'status': 'CONFIRMED',
      'total': '8998.00',
      'customerName': null,
      'customer': {'name': 'Priya', 'phone': '9876543210'},
      'items': [
        {'quantity': 2},
        {'quantity': 1},
      ],
      'createdAt': '2026-09-30T10:00:00.000Z',
    });
    expect(o.customerName, 'Priya');
    expect(o.itemCount, 3);
    expect(o.totalAmount, 8998);
  });
}
