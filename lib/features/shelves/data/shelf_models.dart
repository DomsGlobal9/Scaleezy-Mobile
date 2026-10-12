import 'package:scaleezy/core/utils/json_parse.dart';

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
    id: asString(j['id']),
    parentId: asOptString(j['parentId']),
    kind: asString(j['kind']),
    code: asString(j['code']),
    address: asString(j['address']),
    name: asOptString(j['name']),
    labelCode: asOptString(j['labelCode']),
    capacity: j['capacity'] == null ? null : asInt(j['capacity']),
    isShopFloor: j['isShopFloor'] == true,
    active: j['active'] != false,
    pieces: asInt(j['pieces']),
    items: asInt(j['items']),
    branchPieces: asInt(j['branchPieces'] ?? j['pieces']),
    children: asMaps(j['children']).map(ShelfSpot.fromJson).toList(),
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
    final loc = asMap(j['location']);
    final pieces = asMap(j['pieces']);
    return ShelfTree(
      locationId: asString(loc['id']),
      locationName: asString(loc['name']),
      spots: asMaps(j['spots']).map(ShelfSpot.fromJson).toList(),
      count: asInt(j['count']),
      totalPieces: asInt(pieces['total']),
      onShelves: asInt(pieces['onShelves']),
      notShelved: asInt(pieces['notShelved']),
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
    variantId: asString(j['variantId']),
    productId: asString(j['productId']),
    title: asString(j['title']),
    sku: asString(j['sku']),
    barcode: asOptString(j['barcode']),
    colorName: asOptString(j['colorName']),
    colorHex: asHexColor(j['hexCode']),
    size: asOptString(j['size']),
    imageUrl: asOptString(j['imageUrl']),
    archived: j['archived'] == true,
    quantity: asInt(j['quantity']),
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
    final spot = asMap(j['spot']);
    final loc = asMap(spot['location']);
    return SpotContents(
      spotId: asString(spot['id']),
      address: asString(spot['address']),
      name: asOptString(spot['name']),
      kind: asString(spot['kind']),
      labelCode: asOptString(spot['labelCode']),
      locationId: asString(loc['id']),
      locationName: asString(loc['name']),
      capacity: spot['capacity'] == null ? null : asInt(spot['capacity']),
      holdsStock: spot['holdsStock'] != false,
      total: asInt(j['total']),
      overCapacity: j['overCapacity'] == true,
      items: asMaps(j['items']).map(ShelfItem.fromJson).toList(),
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
    spotId: asString(j['spotId']),
    address: asString(j['address']),
    name: asOptString(j['name']),
    quantity: asInt(j['quantity']),
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
    locationId: asString(j['locationId']),
    location: asString(j['location']),
    total: asInt(j['total']),
    held: asInt(j['held']),
    usesShelves: j['usesShelves'] == true,
    shelves: asMaps(j['shelves']).map(ShelfPlace.fromJson).toList(),
    notShelved: asInt(j['notShelved']),
  );
}

class WhereItem {
  final ShelfItem item;
  final List<WherePlace> places;

  const WhereItem({required this.item, required this.places});

  factory WhereItem.fromJson(Map<String, dynamic> j) => WhereItem(
    item: ShelfItem.fromJson(j),
    places: asMaps(j['places']).map(WherePlace.fromJson).toList(),
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
    total: asInt(j['total']),
    notShelved: asInt(j['notShelved']),
  );
}
