import 'package:scaleezy/core/utils/json_parse.dart';

/// A confirmed order at one store with pieces still to send out (`GET /shelves/pick/orders`).
class PickOrder {
  final String id;
  final String orderNumber;
  final String channel; // POS, ONLINE, …
  final String? source; // SHOPIFY, …
  final String? handover; // KEEP_FOR_CUSTOMER, …
  final String status; // CONFIRMED, PARTIALLY_DISPATCHED
  final DateTime createdAt;
  final String? customer;
  final int lines;
  final int pieces;

  const PickOrder({
    required this.id,
    required this.orderNumber,
    required this.channel,
    this.source,
    this.handover,
    required this.status,
    required this.createdAt,
    this.customer,
    required this.lines,
    required this.pieces,
  });

  bool get partlySent => status == 'PARTIALLY_DISPATCHED';

  /// Where the order came from, as the web names it.
  String get channelName => source == 'SHOPIFY'
      ? 'Shopify'
      : channel == 'ONLINE'
      ? 'Online'
      : handover == 'KEEP_FOR_CUSTOMER'
      ? 'Kept for customer'
      : channel == 'POS'
      ? 'Counter'
      : channel.toLowerCase();

  factory PickOrder.fromJson(Map<String, dynamic> j) => PickOrder(
    id: asString(j['id']),
    orderNumber: asString(j['orderNumber']),
    channel: asString(j['channel']),
    source: asOptString(j['source']),
    handover: asOptString(j['handover']),
    status: asString(j['status']),
    createdAt: asDateOrNow(j['createdAt']),
    customer: asOptString(j['customer']),
    lines: asInt(j['lines']),
    pieces: asInt(j['pieces']),
  );
}

/// The size and colour to pick, as the pick list describes it.
class PickItem {
  final String variantId;
  final String title;
  final String sku;
  final String? code;
  final String? barcode;
  final String? colorName;
  final String? size;
  final String? imageUrl;

  const PickItem({
    required this.variantId,
    required this.title,
    required this.sku,
    this.code,
    this.barcode,
    this.colorName,
    this.size,
    this.imageUrl,
  });

  /// "Red · Size M · SKU-1", as the website's `itemDetail`.
  String get detail => [
    ?colorName,
    if (size != null) size == 'Free' ? size! : 'Size $size',
    sku,
  ].join(' · ');

  /// A scanned or typed tag that is this item's barcode, SKU or code.
  bool matches(String typed) {
    final t = typed.trim().toLowerCase();
    return [barcode, sku, code].any((v) => v != null && v.toLowerCase() == t);
  }

  factory PickItem.fromJson(Map<String, dynamic> j) => PickItem(
    variantId: asString(j['variantId']),
    title: asString(j['title']),
    sku: asString(j['sku']),
    code: asOptString(j['code']),
    barcode: asOptString(j['barcode']),
    colorName: asOptString(j['colorName']),
    size: asOptString(j['size']),
    imageUrl: asOptString(j['imageUrl']),
  );
}

/// Pieces of one order line to take from one place.
class Pick {
  final String orderId;
  final String orderNumber;
  final String salesOrderItemId;
  final int quantity;
  final PickItem item;

  const Pick({
    required this.orderId,
    required this.orderNumber,
    required this.salesOrderItemId,
    required this.quantity,
    required this.item,
  });

  factory Pick.fromJson(Map<String, dynamic> j) => Pick(
    orderId: asString(j['orderId']),
    orderNumber: asString(j['orderNumber']),
    salesOrderItemId: asString(j['salesOrderItemId']),
    quantity: asInt(j['quantity']),
    item: PickItem.fromJson(asMap(j['item'])),
  );
}

/// One shelf on the walk and what to take from it.
class PickStop {
  final String spotId;
  final String address;
  final String? name;
  final int? colour;
  final bool isShopFloor;
  final String? labelCode;
  final List<Pick> picks;

  const PickStop({
    required this.spotId,
    required this.address,
    this.name,
    this.colour,
    this.isShopFloor = false,
    this.labelCode,
    required this.picks,
  });

  factory PickStop.fromJson(Map<String, dynamic> j) => PickStop(
    spotId: asString(j['spotId']),
    address: asString(j['address']),
    name: asOptString(j['name']),
    colour: asHexColor(j['colour']),
    isShopFloor: j['isShopFloor'] == true,
    labelCode: asOptString(j['labelCode']),
    picks: asMaps(j['picks']).map(Pick.fromJson).toList(),
  );
}

/// One walk through a store's shelves for the chosen orders (`GET /shelves/pick/list`).
class PickList {
  /// Order id → order number, oldest order first.
  final Map<String, String> orders;
  final List<PickStop> stops;

  /// In the store but on no shelf.
  final List<Pick> notShelved;

  /// Not in the store at all.
  final List<Pick> short;
  final int pieces;

  const PickList({
    required this.orders,
    required this.stops,
    required this.notShelved,
    required this.short,
    required this.pieces,
  });

  factory PickList.fromJson(Map<String, dynamic> j) => PickList(
    orders: {
      for (final o in asMaps(j['orders']))
        asString(o['id']): asString(o['orderNumber']),
    },
    stops: asMaps(j['stops']).map(PickStop.fromJson).toList(),
    notShelved: asMaps(j['notShelved']).map(Pick.fromJson).toList(),
    short: asMaps(j['short']).map(Pick.fromJson).toList(),
    pieces: asInt(j['pieces']),
  );
}

/// One order line going out, and the shelves its pieces were taken from (spot id → pieces).
class DispatchLine {
  final String salesOrderItemId;
  final int quantity;
  final Map<String, int> fromSpots;

  const DispatchLine({
    required this.salesOrderItemId,
    required this.quantity,
    this.fromSpots = const {},
  });

  Map<String, dynamic> toJson() => {
    'salesOrderItemId': salesOrderItemId,
    'quantity': quantity,
    if (fromSpots.isNotEmpty)
      'fromSpots': [
        for (final e in fromSpots.entries)
          {'spotId': e.key, 'quantity': e.value},
      ],
  };
}
