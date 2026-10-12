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

/// One change to a customer's points or store credit, newest first.
class BalanceEntry {
  final String id;

  /// The server's words, e.g. "Earned on a purchase", "From a return".
  final String label;

  /// Signed: points for loyalty, rupees for store credit.
  final double change;
  final String? note;

  /// The return or bill number it came from, when there is one.
  final String? reference;
  final DateTime at;

  const BalanceEntry({
    required this.id,
    required this.label,
    required this.change,
    this.note,
    this.reference,
    required this.at,
  });

  factory BalanceEntry.fromJson(Map<String, dynamic> j) => BalanceEntry(
    id: asString(j['id']),
    label: asOptString(j['label']) ?? asString(j['kind']),
    // Points entries carry `points`, store credit entries carry `amount`.
    change: asMoney(j['points'] ?? j['amount']) ?? 0,
    note: asOptString(j['note']),
    reference: asOptString(j['returnNumber']) ?? asOptString(j['orderNumber']),
    at: asDateOrNow(j['at']),
  );
}

/// GET /loyalty/customers/:id. Answered even when the shop has loyalty off.
class CustomerPoints {
  final bool enabled;
  final int points;

  /// Rupees the points are worth at the shop's rate.
  final double value;

  /// When the points lapse unless the customer visits; null when none are held.
  final DateTime? lapsesOn;
  final List<BalanceEntry> entries;

  const CustomerPoints({
    required this.enabled,
    required this.points,
    required this.value,
    this.lapsesOn,
    this.entries = const [],
  });

  /// As on the web: nothing to show when loyalty is off and they never had any.
  bool get worthShowing => enabled || points != 0 || entries.isNotEmpty;

  factory CustomerPoints.fromJson(Map<String, dynamic> j) => CustomerPoints(
    enabled: j['enabled'] == true,
    points: asInt(j['points']),
    value: asMoney(j['value']) ?? 0,
    lapsesOn: asDate(j['lapsesOn']),
    entries: asMaps(j['entries']).map(BalanceEntry.fromJson).toList(),
  );
}

/// GET /counter-returns/credit/customers/:id: what returns left them to spend in the shop.
class StoreCredit {
  final double credit;
  final List<BalanceEntry> entries;

  const StoreCredit({required this.credit, this.entries = const []});

  bool get worthShowing => credit != 0 || entries.isNotEmpty;

  factory StoreCredit.fromJson(Map<String, dynamic> j) => StoreCredit(
    credit: asMoney(j['credit']) ?? 0,
    entries: asMaps(j['entries']).map(BalanceEntry.fromJson).toList(),
  );
}
