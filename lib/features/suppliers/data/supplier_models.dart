import 'package:scaleezy/core/utils/json_parse.dart';

class Supplier {
  final String id;
  final String code;
  final String name;
  final String? email;
  final String? phone;
  final String? address;
  final bool active;
  final int purchaseOrders;

  const Supplier({
    required this.id,
    required this.code,
    required this.name,
    this.email,
    this.phone,
    this.address,
    required this.active,
    required this.purchaseOrders,
  });

  factory Supplier.fromJson(Map<String, dynamic> j) => Supplier(
    id: asString(j['id']),
    code: asString(j['supplierCode']),
    name: asString(j['name']),
    email: asOptString(j['email']),
    phone: asOptString(j['phone']),
    address: asOptString(j['address']),
    active: j['isActive'] != false,
    purchaseOrders: asInt(asMap(j['_count'])['purchaseOrders']),
  );
}
