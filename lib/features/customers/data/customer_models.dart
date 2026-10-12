import 'package:scaleezy/core/utils/json_parse.dart';
import 'package:scaleezy/features/orders/data/order_models.dart';

class Customer {
  final String id;
  final String code;
  final String name;
  final String? companyName;
  final String? phone;
  final String? email;
  final String? gstNumber;
  final String? billingAddress;
  final String status;
  final List<String> tags;
  final String? notes;
  final DateTime? createdAt;

  /// Only on GET /customers/:id.
  final List<OrderItemSummary> orders;

  const Customer({
    required this.id,
    required this.code,
    required this.name,
    this.companyName,
    this.phone,
    this.email,
    this.gstNumber,
    this.billingAddress,
    required this.status,
    this.tags = const [],
    this.notes,
    this.createdAt,
    this.orders = const [],
  });

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
    id: asString(j['id']),
    code: asString(j['customerCode']),
    name: asOptString(j['name']) ?? 'Unnamed',
    companyName: asOptString(j['companyName']),
    phone: asOptString(j['phone']),
    email: asOptString(j['email']),
    gstNumber: asOptString(j['gstNumber']),
    billingAddress: asOptString(j['billingAddress']),
    status: asString(j['status']),
    tags: (j['tags'] as List? ?? const []).map(asString).toList(),
    notes: asOptString(j['notes']),
    createdAt: asDate(j['createdAt']),
    orders: asMaps(j['salesOrders']).map(OrderItemSummary.fromJson).toList(),
  );
}
