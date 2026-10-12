import 'package:scaleezy/core/utils/json_parse.dart';

class PurchaseOrderSummary {
  final String id;
  final String poNumber;
  final String status; // DRAFT, SENT, PARTIALLY_RECEIVED, RECEIVED, CANCELLED
  final String supplierName;
  final double? totalAmount; // hidden without cost:view
  final DateTime? expectedDelivery;
  final DateTime createdAt;
  final int lineCount;

  /// The store the order is for: its name, id, and whether it can still take stock in.
  final String? deliverTo;
  final String? deliverToId;
  final bool deliverToActive;

  const PurchaseOrderSummary({
    required this.id,
    required this.poNumber,
    required this.status,
    required this.supplierName,
    this.totalAmount,
    this.expectedDelivery,
    required this.createdAt,
    required this.lineCount,
    this.deliverTo,
    this.deliverToId,
    this.deliverToActive = false,
  });

  bool get canReceive => status == 'SENT' || status == 'PARTIALLY_RECEIVED';

  factory PurchaseOrderSummary.fromJson(Map<String, dynamic> j) =>
      PurchaseOrderSummary(
        id: asString(j['id']),
        poNumber: asString(j['poNumber']),
        status: asString(j['status']),
        supplierName: asString(asMap(j['supplier'])['name']),
        totalAmount: asMoney(j['totalAmount']),
        expectedDelivery: asDate(j['expectedDeliveryDate']),
        createdAt: asDate(j['createdAt']) ?? DateTime.now(),
        lineCount: j['_count'] != null
            ? asInt(asMap(j['_count'])['items'])
            : asMaps(j['items']).length,
        deliverTo: asOptString(asMap(j['location'])['name']),
        deliverToId: asOptString(asMap(j['location'])['id']),
        deliverToActive: asMap(j['location'])['active'] == true,
      );
}

class PurchaseOrderLine {
  final String id;
  final String variantId;
  final String title;
  final String sku;
  final String? barcode;
  final String? color;
  final String? size;
  final int ordered;
  final int received;
  final double? unitPrice;

  const PurchaseOrderLine({
    required this.id,
    required this.variantId,
    required this.title,
    required this.sku,
    this.barcode,
    this.color,
    this.size,
    required this.ordered,
    required this.received,
    this.unitPrice,
  });

  int get outstanding => (ordered - received).clamp(0, ordered);

  factory PurchaseOrderLine.fromJson(Map<String, dynamic> j) =>
      PurchaseOrderLine(
        id: asString(j['id']),
        variantId: asString(j['variantId']),
        title: asString(j['productTitle']),
        sku: asString(j['sku']),
        barcode: asOptString(j['barcode']),
        color: asOptString(j['color']),
        size: asOptString(j['size']),
        ordered: asInt(j['orderedQty']),
        received: asInt(j['receivedQty']),
        unitPrice: asMoney(j['unitPrice']),
      );
}

class PurchaseOrderDetail {
  final PurchaseOrderSummary summary;
  final String? supplierPhone;
  final String? notes;
  final List<PurchaseOrderLine> lines;

  const PurchaseOrderDetail({
    required this.summary,
    this.supplierPhone,
    this.notes,
    required this.lines,
  });

  factory PurchaseOrderDetail.fromJson(Map<String, dynamic> j) {
    final lines = asMaps(j['items']).map(PurchaseOrderLine.fromJson).toList();
    final summary = PurchaseOrderSummary.fromJson(j);
    return PurchaseOrderDetail(
      summary: summary,
      supplierPhone: asOptString(asMap(j['supplier'])['phone']),
      notes: asOptString(j['notes']),
      lines: lines,
    );
  }
}
