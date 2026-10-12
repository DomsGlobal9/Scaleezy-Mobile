// Shapes for the modules under "More", read from inventory_backend (main).

import 'inventory_models.dart';

double? _money(dynamic v) =>
    v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);
int _int(dynamic v) =>
    v is num ? v.toInt() : (v is String ? int.tryParse(v) ?? 0 : 0);
String _str(dynamic v) => v is String ? v : (v?.toString() ?? '');
String? _opt(dynamic v) => v is String && v.trim().isNotEmpty ? v : null;
DateTime? _date(dynamic v) =>
    v is String ? DateTime.tryParse(v)?.toLocal() : null;
Map<String, dynamic> _map(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : const {};
List<Map<String, dynamic>> _maps(dynamic v) => v is List
    ? v.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
    : const [];
int? _hex(dynamic v) {
  final s = _opt(v)?.replaceFirst('#', '');
  if (s == null || s.length != 6) return null;
  final n = int.tryParse(s, radix: 16);
  return n == null ? null : 0xFF000000 | n;
}

// ---- Shelves ------------------------------------------------------------------------------------

/// A rack, shelf, box… anywhere inside a location that pieces sit.
class ShelfSpot {
  final String id;
  final String? parentId;
  final String kind; // AREA, RACK, CUPBOARD, SHELF, BOX, STACK, BUNDLE, RAIL
  final String code;
  final String address; // e.g. "R1-S3"
  final String? name;
  final String? labelCode;
  final int? capacity;
  final bool isShopFloor;
  final bool active;
  final int pieces;
  final int items;
  final int branchPieces;
  final List<ShelfSpot> children;

  const ShelfSpot({
    required this.id,
    this.parentId,
    required this.kind,
    required this.code,
    required this.address,
    this.name,
    this.labelCode,
    this.capacity,
    this.isShopFloor = false,
    this.active = true,
    this.pieces = 0,
    this.items = 0,
    this.branchPieces = 0,
    this.children = const [],
  });

  bool get holdsStock => children.isEmpty;
  String get title => name ?? address;

  factory ShelfSpot.fromJson(Map<String, dynamic> j) => ShelfSpot(
    id: _str(j['id']),
    parentId: _opt(j['parentId']),
    kind: _str(j['kind']),
    code: _str(j['code']),
    address: _str(j['address']),
    name: _opt(j['name']),
    labelCode: _opt(j['labelCode']),
    capacity: j['capacity'] == null ? null : _int(j['capacity']),
    isShopFloor: j['isShopFloor'] == true,
    active: j['active'] != false,
    pieces: _int(j['pieces']),
    items: _int(j['items']),
    branchPieces: _int(j['branchPieces'] ?? j['pieces']),
    children: _maps(j['children']).map(ShelfSpot.fromJson).toList(),
  );

  /// Every spot in the branch, depth first.
  Iterable<ShelfSpot> get flatten sync* {
    yield this;
    for (final c in children) {
      yield* c.flatten;
    }
  }
}

class ShelfTree {
  final String locationId;
  final String locationName;
  final List<ShelfSpot> spots;
  final int count;
  final int totalPieces;
  final int onShelves;
  final int notShelved;

  const ShelfTree({
    required this.locationId,
    required this.locationName,
    required this.spots,
    required this.count,
    required this.totalPieces,
    required this.onShelves,
    required this.notShelved,
  });

  factory ShelfTree.fromJson(Map<String, dynamic> j) {
    final loc = _map(j['location']);
    final pieces = _map(j['pieces']);
    return ShelfTree(
      locationId: _str(loc['id']),
      locationName: _str(loc['name']),
      spots: _maps(j['spots']).map(ShelfSpot.fromJson).toList(),
      count: _int(j['count']),
      totalPieces: _int(pieces['total']),
      onShelves: _int(pieces['onShelves']),
      notShelved: _int(pieces['notShelved']),
    );
  }
}

/// A size and colour as the shelves module describes it.
class ShelfItem {
  final String variantId;
  final String productId;
  final String title;
  final String sku;
  final String? barcode;
  final String? colorName;
  final int? colorHex;
  final String? size;
  final String? imageUrl;
  final bool archived;
  final int quantity; // on this spot, when read from a spot

  const ShelfItem({
    required this.variantId,
    required this.productId,
    required this.title,
    required this.sku,
    this.barcode,
    this.colorName,
    this.colorHex,
    this.size,
    this.imageUrl,
    this.archived = false,
    this.quantity = 0,
  });

  String get label => [?colorName, if (size != null) 'Size $size'].join(' • ');

  factory ShelfItem.fromJson(Map<String, dynamic> j) => ShelfItem(
    variantId: _str(j['variantId']),
    productId: _str(j['productId']),
    title: _str(j['title']),
    sku: _str(j['sku']),
    barcode: _opt(j['barcode']),
    colorName: _opt(j['colorName']),
    colorHex: _hex(j['hexCode']),
    size: _opt(j['size']),
    imageUrl: _opt(j['imageUrl']),
    archived: j['archived'] == true,
    quantity: _int(j['quantity']),
  );
}

class SpotContents {
  final String spotId;
  final String address;
  final String? name;
  final String kind;
  final String? labelCode;
  final String locationId;
  final String locationName;
  final int? capacity;
  final bool holdsStock;
  final int total;
  final bool overCapacity;
  final List<ShelfItem> items;

  const SpotContents({
    required this.spotId,
    required this.address,
    this.name,
    required this.kind,
    this.labelCode,
    required this.locationId,
    required this.locationName,
    this.capacity,
    required this.holdsStock,
    required this.total,
    required this.overCapacity,
    required this.items,
  });

  factory SpotContents.fromJson(Map<String, dynamic> j) {
    final spot = _map(j['spot']);
    final loc = _map(spot['location']);
    return SpotContents(
      spotId: _str(spot['id']),
      address: _str(spot['address']),
      name: _opt(spot['name']),
      kind: _str(spot['kind']),
      labelCode: _opt(spot['labelCode']),
      locationId: _str(loc['id']),
      locationName: _str(loc['name']),
      capacity: spot['capacity'] == null ? null : _int(spot['capacity']),
      holdsStock: spot['holdsStock'] != false,
      total: _int(j['total']),
      overCapacity: j['overCapacity'] == true,
      items: _maps(j['items']).map(ShelfItem.fromJson).toList(),
    );
  }
}

class ShelfPlace {
  final String spotId;
  final String address;
  final String? name;
  final int quantity;

  const ShelfPlace({
    required this.spotId,
    required this.address,
    this.name,
    required this.quantity,
  });

  factory ShelfPlace.fromJson(Map<String, dynamic> j) => ShelfPlace(
    spotId: _str(j['spotId']),
    address: _str(j['address']),
    name: _opt(j['name']),
    quantity: _int(j['quantity']),
  );
}

/// One location's share of a piece: on which shelves, and how many are not on any.
class WherePlace {
  final String locationId;
  final String location;
  final int total;
  final int held;
  final bool usesShelves;
  final List<ShelfPlace> shelves;
  final int notShelved;

  const WherePlace({
    required this.locationId,
    required this.location,
    required this.total,
    required this.held,
    required this.usesShelves,
    required this.shelves,
    required this.notShelved,
  });

  factory WherePlace.fromJson(Map<String, dynamic> j) => WherePlace(
    locationId: _str(j['locationId']),
    location: _str(j['location']),
    total: _int(j['total']),
    held: _int(j['held']),
    usesShelves: j['usesShelves'] == true,
    shelves: _maps(j['shelves']).map(ShelfPlace.fromJson).toList(),
    notShelved: _int(j['notShelved']),
  );
}

class WhereItem {
  final ShelfItem item;
  final List<WherePlace> places;

  const WhereItem({required this.item, required this.places});

  factory WhereItem.fromJson(Map<String, dynamic> j) => WhereItem(
    item: ShelfItem.fromJson(j),
    places: _maps(j['places']).map(WherePlace.fromJson).toList(),
  );
}

class NotShelvedItem {
  final ShelfItem item;
  final int total;
  final int notShelved;

  const NotShelvedItem({
    required this.item,
    required this.total,
    required this.notShelved,
  });

  factory NotShelvedItem.fromJson(Map<String, dynamic> j) => NotShelvedItem(
    item: ShelfItem.fromJson(j),
    total: _int(j['total']),
    notShelved: _int(j['notShelved']),
  );
}

// ---- Customers ----------------------------------------------------------------------------------

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
    id: _str(j['id']),
    code: _str(j['customerCode']),
    name: _opt(j['name']) ?? 'Unnamed',
    companyName: _opt(j['companyName']),
    phone: _opt(j['phone']),
    email: _opt(j['email']),
    gstNumber: _opt(j['gstNumber']),
    billingAddress: _opt(j['billingAddress']),
    status: _str(j['status']),
    tags: (j['tags'] as List? ?? const []).map(_str).toList(),
    notes: _opt(j['notes']),
    createdAt: _date(j['createdAt']),
    orders: _maps(j['salesOrders']).map(OrderItemSummary.fromJson).toList(),
  );
}

// ---- Suppliers & purchase orders ----------------------------------------------------------------

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
    id: _str(j['id']),
    code: _str(j['supplierCode']),
    name: _str(j['name']),
    email: _opt(j['email']),
    phone: _opt(j['phone']),
    address: _opt(j['address']),
    active: j['isActive'] != false,
    purchaseOrders: _int(_map(j['_count'])['purchaseOrders']),
  );
}

class PurchaseOrderSummary {
  final String id;
  final String poNumber;
  final String status; // DRAFT, SENT, PARTIALLY_RECEIVED, RECEIVED, CANCELLED
  final String supplierName;
  final double? totalAmount; // hidden without cost:view
  final DateTime? expectedDelivery;
  final DateTime createdAt;
  final int lineCount;
  final String? deliverTo;

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
  });

  bool get canReceive => status == 'SENT' || status == 'PARTIALLY_RECEIVED';

  factory PurchaseOrderSummary.fromJson(Map<String, dynamic> j) =>
      PurchaseOrderSummary(
        id: _str(j['id']),
        poNumber: _str(j['poNumber']),
        status: _str(j['status']),
        supplierName: _str(_map(j['supplier'])['name']),
        totalAmount: _money(j['totalAmount']),
        expectedDelivery: _date(j['expectedDeliveryDate']),
        createdAt: _date(j['createdAt']) ?? DateTime.now(),
        lineCount: j['_count'] != null
            ? _int(_map(j['_count'])['items'])
            : _maps(j['items']).length,
        deliverTo: _opt(_map(j['location'])['name']),
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
        id: _str(j['id']),
        variantId: _str(j['variantId']),
        title: _str(j['productTitle']),
        sku: _str(j['sku']),
        barcode: _opt(j['barcode']),
        color: _opt(j['color']),
        size: _opt(j['size']),
        ordered: _int(j['orderedQty']),
        received: _int(j['receivedQty']),
        unitPrice: _money(j['unitPrice']),
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
    final lines = _maps(j['items']).map(PurchaseOrderLine.fromJson).toList();
    final summary = PurchaseOrderSummary.fromJson(j);
    return PurchaseOrderDetail(
      summary: summary,
      supplierPhone: _opt(_map(j['supplier'])['phone']),
      notes: _opt(j['notes']),
      lines: lines,
    );
  }
}

// ---- Team ---------------------------------------------------------------------------------------

class TeamMember {
  final String id;
  final String name;
  final String email;
  final String status;
  final List<String> roles;
  final DateTime? lastActiveAt;

  const TeamMember({
    required this.id,
    required this.name,
    required this.email,
    required this.status,
    required this.roles,
    this.lastActiveAt,
  });

  factory TeamMember.fromJson(Map<String, dynamic> j) => TeamMember(
    id: _str(j['id']),
    name: _opt(j['name']) ?? _str(j['email']),
    email: _str(j['email']),
    status: _str(j['status']),
    roles: _maps(j['roles'])
        .map((r) => _str(_map(r['role'])['name']))
        .where((n) => n.isNotEmpty)
        .toList(),
    lastActiveAt: _date(j['lastActiveAt']) ?? _date(j['lastLoginAt']),
  );
}
