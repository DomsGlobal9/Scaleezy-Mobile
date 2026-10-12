import 'package:scaleezy/core/utils/json_parse.dart';

class StockLocation {
  final String id;
  final String code;
  final String name;
  final String type; // STORE, ONLINE, WAREHOUSE
  final bool active;

  const StockLocation({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    required this.active,
  });

  factory StockLocation.fromJson(Map<String, dynamic> j) => StockLocation(
    id: asString(j['id']),
    code: asString(j['code']),
    name: asOptString(j['name']) ?? asString(j['code']),
    type: asString(j['type']),
    active: j['active'] != false,
  );
}

class Branding {
  final String? businessName;
  final String? logoUrl;
  final String? businessAddress;
  final String? businessPhone;

  const Branding({
    this.businessName,
    this.logoUrl,
    this.businessAddress,
    this.businessPhone,
  });

  factory Branding.fromJson(Map<String, dynamic> j) => Branding(
    businessName: asOptString(j['businessName']),
    logoUrl: asOptString(j['logoUrl']),
    businessAddress: asOptString(j['businessAddress']),
    businessPhone: asOptString(j['businessPhone']),
  );
}
