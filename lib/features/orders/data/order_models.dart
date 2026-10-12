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
  });

  factory OrderItemSummary.fromJson(Map<String, dynamic> j) {
    final customer = j['customer'] is Map
        ? Map<String, dynamic>.from(j['customer'])
        : const {};
    final items = asMaps(j['items']);
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
    );
  }
}

class OrderLine {
  final String title;
  final String sku;
  final String size;
  final String colorName;
  final int quantity;
  final int fulfilledQty;
  final double unitPrice;
  final double totalPrice;

  const OrderLine({
    required this.title,
    required this.sku,
    required this.size,
    required this.colorName,
    required this.quantity,
    required this.fulfilledQty,
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

  const OrderDetail({
    required this.summary,
    required this.subtotal,
    required this.discountAmount,
    required this.taxAmount,
    required this.shippingAmount,
    required this.lines,
  });

  factory OrderDetail.fromJson(Map<String, dynamic> j) => OrderDetail(
    summary: OrderItemSummary.fromJson(j),
    subtotal: asMoney(j['subtotal']) ?? 0,
    discountAmount: asMoney(j['discountAmount']) ?? 0,
    taxAmount: asMoney(j['taxAmount']) ?? 0,
    shippingAmount: asMoney(j['shippingAmount']) ?? 0,
    lines: asMaps(j['items']).map(OrderLine.fromJson).toList(),
  );
}
