import 'package:scaleezy/core/utils/json_parse.dart';

class OrderItemSummary {
  final String id;
  final String orderNumber;
  final String customerName;
  final String customerPhone;
  final String
  status; // DRAFT, CONFIRMED, PARTIALLY_DISPATCHED, DISPATCHED, CANCELLED
  final double totalAmount;
  final int itemCount;
  final DateTime date;
  final bool atCounter;

  /// SCALEEZY_POS, SHOPIFY, the counter's own value, or null for an order typed in by hand.
  final String? sourceSystem;

  /// ONLINE, MARKETPLACE, ... as the server stores it.
  final String? channel;
  final String? createdByName;
  final String? locationName;

  /// The server's payment summary (payment-rules.ts paymentSummary): PAID, PART_PAID, UNPAID,
  /// REFUNDED or WRITTEN_OFF, with what was paid, is still due and was written off.
  final String? paymentStatus;
  final double paid;
  final double due;
  final double writtenOff;

  const OrderItemSummary({
    required this.id,
    required this.orderNumber,
    required this.customerName,
    required this.customerPhone,
    required this.status,
    required this.totalAmount,
    required this.itemCount,
    required this.date,
    this.atCounter = false,
    this.sourceSystem,
    this.channel,
    this.createdByName,
    this.locationName,
    this.paymentStatus,
    this.paid = 0,
    this.due = 0,
    this.writtenOff = 0,
  });

  factory OrderItemSummary.fromJson(Map<String, dynamic> j) {
    final customer = j['customer'] is Map
        ? Map<String, dynamic>.from(j['customer'])
        : const {};
    final items = asMaps(j['items']);
    final payment = asMap(j['payment']);
    return OrderItemSummary(
      id: asString(j['id']),
      orderNumber: asString(j['orderNumber']),
      customerName:
          asOptString(j['customerName']) ??
          asOptString(customer['name']) ??
          asOptString(customer['companyName']) ??
          'Walk-in customer',
      customerPhone:
          asOptString(j['customerPhone']) ?? asString(customer['phone']),
      status: asString(j['status']),
      totalAmount: asMoney(j['total']) ?? 0,
      itemCount: items.fold(0, (sum, i) => sum + asInt(i['quantity'])),
      date: asDateOrNow(j['createdAt']),
      atCounter: j['atCounter'] == true,
      sourceSystem: asOptString(j['sourceSystem']),
      channel: asOptString(j['channel']),
      createdByName: asOptString(asMap(j['createdBy'])['name']),
      locationName: asOptString(asMap(j['location'])['name']),
      paymentStatus: asOptString(payment['status']),
      paid: asMoney(payment['paid']) ?? 0,
      due: asMoney(payment['due']) ?? 0,
      writtenOff: asMoney(payment['writtenOff']) ?? 0,
    );
  }

  /// Where the order came from, as a shop says it (the website's `whereFrom`).
  String get whereFrom => atCounter
      ? 'Counter'
      : sourceSystem == 'SCALEEZY_POS'
      ? 'POS till'
      : sourceSystem == 'SHOPIFY'
      ? 'Shopify'
      : channel == 'ONLINE'
      ? 'Online'
      : channel == 'MARKETPLACE'
      ? 'Marketplace'
      : 'Order';

  /// The payment state worth a pill, or null: only orders that take money here or at the POS
  /// till have one (a Shopify order was paid on Shopify), as the website's `paymentPill`.
  /// PART_PAID and UNPAID read "₹X due" with [due].
  String? get paymentShown =>
      !atCounter && sourceSystem != 'SCALEEZY_POS' && !(paid > 0)
      ? null
      : paymentStatus;
}

class OrderLine {
  final String title;
  final String sku;
  final String size;
  final String colorName;
  final int quantity;
  final int fulfilledQty;

  /// Pieces still set aside for this order, read off the live reservations.
  final int heldQty;
  final double unitPrice;
  final double totalPrice;

  const OrderLine({
    required this.title,
    required this.sku,
    required this.size,
    required this.colorName,
    required this.quantity,
    required this.fulfilledQty,
    this.heldQty = 0,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory OrderLine.fromJson(Map<String, dynamic> j) {
    final variant = j['variant'] is Map
        ? Map<String, dynamic>.from(j['variant'])
        : const {};
    final product = variant['product'] is Map
        ? Map<String, dynamic>.from(variant['product'])
        : const {};
    return OrderLine(
      title: asOptString(product['title']) ?? asString(j['productTitle']),
      sku: asOptString(variant['sku']) ?? asString(j['sku']),
      size: asString(variant['size']),
      colorName: asString(variant['colorName']),
      quantity: asInt(j['quantity']),
      fulfilledQty: asInt(j['fulfilledQty']),
      heldQty: asInt(j['heldQty']),
      unitPrice: asMoney(j['unitPrice']) ?? 0,
      totalPrice: asMoney(j['totalPrice']) ?? 0,
    );
  }
}

class OrderDetail {
  final OrderItemSummary summary;
  final double subtotal;
  final double discountAmount;
  final double taxAmount;
  final double shippingAmount;
  final List<OrderLine> lines;

  /// Money taken for the order and paid back, oldest first.
  final List<OrderPayment> payments;

  const OrderDetail({
    required this.summary,
    required this.subtotal,
    required this.discountAmount,
    required this.taxAmount,
    required this.shippingAmount,
    required this.lines,
    this.payments = const [],
  });

  factory OrderDetail.fromJson(Map<String, dynamic> j) => OrderDetail(
    summary: OrderItemSummary.fromJson(j),
    subtotal: asMoney(j['subtotal']) ?? 0,
    discountAmount: asMoney(j['discountAmount']) ?? 0,
    taxAmount: asMoney(j['taxAmount']) ?? 0,
    shippingAmount: asMoney(j['shippingAmount']) ?? 0,
    lines: asMaps(j['items']).map(OrderLine.fromJson).toList(),
    payments: asMaps(j['payments']).map(OrderPayment.fromJson).toList(),
  );
}

/// One payment or refund row on an order.
class OrderPayment {
  /// PAYMENT or REFUND.
  final String kind;
  final String method;
  final double amount;
  final String? reference;
  final DateTime receivedAt;
  final String? receivedBy;
  final double? cashReceived;
  final double changeGiven;

  OrderPayment.fromJson(Map<String, dynamic> j)
    : kind = asString(j['kind']),
      method = asString(j['method']),
      amount = asMoney(j['amount']) ?? 0,
      reference = asOptString(j['reference']),
      receivedAt = asDateOrNow(j['receivedAt']),
      receivedBy = asOptString(asMap(j['receivedBy'])['name']),
      cashReceived = asMoney(j['cashReceived']),
      changeGiven = asMoney(j['changeGiven']) ?? 0;
}
