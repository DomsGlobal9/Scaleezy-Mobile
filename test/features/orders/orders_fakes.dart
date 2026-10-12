import 'package:scaleezy/features/orders/data/order_models.dart';
import 'package:scaleezy/features/orders/data/order_repository.dart';
import 'package:scaleezy/features/orders/data/receipt_models.dart';

import '../products/products_fakes.dart' show offlineClient;

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

/// A counter bill as counter-sale.service.ts getSale() returns it (the `data` of
/// GET /counter-sales/:orderId/receipt): a 5% saree with an offer, 18% stitching (a SAC code),
/// paid part in cash and part by UPI, 98 still due.
Map<String, dynamic> receiptJson({
  bool atCounter = true,
  String? phone = '+91 98480 22338',
}) => {
  'id': 'o1',
  'orderNumber': 'SO-0042',
  'status': 'DISPATCHED',
  'channel': 'POS',
  'handover': 'TAKEN_NOW',
  'atCounter': atCounter,
  'createdAt': '2026-10-12T10:35:00.000Z',
  'soldBy': 'Asha',
  'store': {
    'id': 'l1',
    'name': 'Main Store',
    'address': '12 MG Road, Vijayawada',
    'phone': '+91 86600 12345',
  },
  'customer': {
    'id': 'c1',
    'name': 'Priya Sharma',
    'code': 'CUS-0007',
    'phone': phone,
    'phoneMasked': phone == null ? null : '••••2338',
  },
  'items': [
    {
      'id': 'i1',
      'variantId': 'v1',
      'title': 'Banarasi Saree',
      'sku': 'SAR-RED-F',
      'colorName': 'Red',
      'size': 'Free',
      'quantity': 2,
      'fulfilledQty': 2,
      'listUnitPrice': 1499,
      'lineDiscount': 0,
      'allocatedDiscount': 149.9,
      'unitPrice': 1424.05,
      'totalPrice': 2848.1,
      'priceSource': 'LIST',
      'hsnCode': '5007',
      'taxRateBps': 500,
      'discounts': [
        {'title': 'Festive 5%', 'source': 'OFFER', 'amount': 149.9},
      ],
    },
    {
      'id': 'i2',
      'variantId': 'v2',
      'title': 'Stitching',
      'sku': 'SRV-STITCH',
      'colorName': null,
      'size': null,
      'quantity': 1,
      'fulfilledQty': 1,
      'listUnitPrice': 250,
      'lineDiscount': null,
      'allocatedDiscount': null,
      'unitPrice': 250,
      'totalPrice': 250,
      'priceSource': 'LIST',
      'hsnCode': '998821',
      'taxRateBps': 1800,
      'discounts': [],
    },
  ],
  'discounts': [
    {
      'id': 'd1',
      'source': 'OFFER',
      'title': 'Festive 5%',
      'amount': 149.9,
      'code': null,
    },
  ],
  'subtotal': 3248,
  'discountAmount': 149.9,
  'taxAmount': 0,
  'shippingAmount': 0,
  'roundOff': -0.1,
  'total': 3098,
  'payments': [
    {
      'id': 'p1',
      'kind': 'PAYMENT',
      'method': 'CASH',
      'amount': 2000,
      'cashReceived': 2000,
      'changeGiven': 0,
      'reference': null,
      'receivedAt': '2026-10-12T10:35:00.000Z',
      'receivedBy': 'Asha',
    },
    {
      'id': 'p2',
      'kind': 'PAYMENT',
      'method': 'UPI',
      'amount': 1000,
      'cashReceived': null,
      'changeGiven': null,
      'reference': 'UTR123',
      'receivedAt': '2026-10-12T10:35:00.000Z',
      'receivedBy': 'Asha',
    },
  ],
  'payment': {
    'paid': 3000,
    'refunded': 0,
    'due': 98,
    'writtenOff': 0,
    'status': 'PART_PAID',
  },
  'writtenOff': null,
  'gst': [
    {
      'rateBps': 500,
      'taxable': 2712.48,
      'cgst': 67.81,
      'sgst': 67.81,
      'igst': 0,
    },
    {
      'rateBps': 1800,
      'taxable': 211.86,
      'cgst': 19.07,
      'sgst': 19.07,
      'igst': 0,
    },
  ],
  'buyer': null,
  'shop': {
    'name': 'Lakshmi Silks',
    'logoUrl': null,
    'address': '12 MG Road, Vijayawada',
    'phone': '+91 86600 12345',
    'email': null,
    'gstNumber': '37ABCDE1234F1Z5',
    'receiptFooter': 'No exchange without bill.',
  },
};

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
