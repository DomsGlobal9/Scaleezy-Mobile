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
    expect(o.whereFrom, 'Order');
    expect(o.paymentShown, isNull);
  });

  test('orders list: source, who and the payment summary', () {
    final o = OrderItemSummary.fromJson({
      'id': 'o2',
      'orderNumber': 'SO-0002',
      'status': 'DISPATCHED',
      'total': '3098.00',
      'sourceSystem': 'SCALEEZY_POS',
      'channel': 'POS',
      'atCounter': false,
      'createdBy': {'id': 'u1', 'name': 'Asha'},
      'location': {'id': 'l1', 'name': 'Main Store'},
      'payment': {
        'paid': 3000,
        'refunded': 0,
        'due': 98,
        'writtenOff': 0,
        'status': 'PART_PAID',
      },
      'createdAt': '2026-10-12T10:35:00.000Z',
    });
    expect(o.whereFrom, 'POS till');
    expect(o.createdByName, 'Asha');
    expect(o.locationName, 'Main Store');
    expect(o.paid, 3000);
    expect(o.due, 98);
    expect(o.paymentShown, 'PART_PAID');
  });

  OrderItemSummary from({
    bool atCounter = false,
    String? source,
    String? channel,
    String status = 'PAID',
    num paid = 0,
  }) => OrderItemSummary.fromJson({
    'atCounter': atCounter,
    'sourceSystem': source,
    'channel': channel,
    'payment': {'status': status, 'paid': paid, 'due': 0},
  });

  test('where from reads as the website says it', () {
    expect(from(atCounter: true, source: 'X').whereFrom, 'Counter');
    expect(from(source: 'SHOPIFY').whereFrom, 'Shopify');
    expect(from(channel: 'ONLINE').whereFrom, 'Online');
    expect(from(channel: 'MARKETPLACE').whereFrom, 'Marketplace');
  });

  test('a payment pill only where money is taken here or at the till', () {
    // Paid on Shopify, nothing taken here: no pill.
    expect(from(source: 'SHOPIFY', status: 'UNPAID').paymentShown, isNull);
    // Money recorded here does get one, wherever the order came from.
    expect(from(source: 'SHOPIFY', paid: 10).paymentShown, 'PAID');
    expect(from(atCounter: true, status: 'REFUNDED').paymentShown, 'REFUNDED');
    expect(
      from(source: 'SCALEEZY_POS', status: 'WRITTEN_OFF').paymentShown,
      'WRITTEN_OFF',
    );
  });

  test('order detail: held pieces and payment rows', () {
    final d = OrderDetail.fromJson({
      'id': 'o1',
      'orderNumber': 'SO-0001',
      'status': 'PARTIALLY_DISPATCHED',
      'total': '2998.00',
      'items': [
        {'quantity': 2, 'fulfilledQty': 1, 'heldQty': 1},
      ],
      'payments': [
        {
          'id': 'p1',
          'kind': 'PAYMENT',
          'method': 'CASH',
          'amount': '3000.00',
          'cashReceived': '3000.00',
          'changeGiven': '2.00',
          'reference': null,
          'receivedAt': '2026-10-12T10:35:00.000Z',
          'receivedBy': {'name': 'Asha'},
        },
      ],
    });
    expect(d.lines.single.heldQty, 1);
    expect(d.lines.single.fulfilledQty, 1);
    final p = d.payments.single;
    expect(p.method, 'CASH');
    expect(p.amount, 3000);
    expect(p.changeGiven, 2);
    expect(p.receivedBy, 'Asha');
    expect(p.reference, isNull);
  });
}
