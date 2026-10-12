import 'package:scaleezy/core/utils/json_parse.dart';

class TransactionItem {
  final String id;
  final String type; // IN, OUT, ADJUSTMENT
  final String reason;
  final int quantity;
  final int balanceAfter;
  final String reference;
  final String sku;
  final String productTitle;
  final String performedBy;
  final DateTime timestamp;

  const TransactionItem({
    required this.id,
    required this.type,
    required this.reason,
    required this.quantity,
    required this.balanceAfter,
    required this.reference,
    required this.sku,
    required this.productTitle,
    this.performedBy = '',
    required this.timestamp,
  });

  bool get isInbound => quantity > 0;

  factory TransactionItem.fromJson(Map<String, dynamic> j) {
    final variant = j['variant'] is Map
        ? Map<String, dynamic>.from(j['variant'])
        : const {};
    final product = variant['product'] is Map
        ? Map<String, dynamic>.from(variant['product'])
        : const {};
    return TransactionItem(
      id: asString(j['id']),
      type: asString(j['type']),
      reason: asString(j['reason']),
      quantity: asInt(j['quantity']),
      balanceAfter: asInt(j['balanceAfter']),
      reference:
          asOptString(j['referenceType']) ?? asOptString(j['notes']) ?? '',
      sku: asOptString(j['sku']) ?? asString(variant['sku']),
      productTitle:
          asOptString(j['productTitle']) ?? asString(product['title']),
      performedBy: asString(j['createdBy']),
      timestamp: asDateOrNow(j['createdAt']),
    );
  }
}
