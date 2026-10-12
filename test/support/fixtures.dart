/// Payloads as the backend sends them (origin/main of inventory_backend), for the fake API and
/// for model tests. Each builder names the route and the service that shapes it.
///
/// Conventions, as on the wire:
/// - Prisma Decimals are strings with paise (`'1499.00'`); hand-built DTOs send numbers.
/// - Without `cost:view` the cost-visibility middleware deletes [costFields] at any depth:
///   pass `cost: false` (or wrap in [withoutCost]) to get that shape. Absent, never null.
/// - Envelopes differ by module: `ok(data)` (fake_api.dart), [productListJson]'s
///   `{data, meta}`, [itemsPage]'s `{data: {items, pagination}}`, and raw arrays/objects for
///   sales orders.
library;

import 'fake_api.dart' show ok;

// ---- Envelopes and cost --------------------------------------------------------------------

/// `{success, data: {items, pagination}}`: /inventory/variants, /variants/search.
Map<String, Object?> itemsPage(
  List<Object?> items, {
  int page = 1,
  int limit = 20,
  int? total,
}) => ok({
  'items': items,
  'pagination': _pagination(page, limit, total ?? items.length),
});

Map<String, Object?> _pagination(int page, int limit, int total) => {
  'page': page,
  'limit': limit,
  'total': total,
  'pages': total == 0 ? 0 : (total / limit).ceil(),
};

/// The backend's COST_FIELDS (cost-visibility.middleware.ts), removed at any depth for a person
/// without cost:view, as its withoutKeys does.
const costFields = {
  'costPrice',
  'averageCost',
  'lastPurchaseCost',
  'lastCostUpdatedAt',
  'previousAverageCost',
  'newAverageCost',
  'inventoryValue',
  'totalValue',
  'unitCost',
  'totalCost',
  'grossProfit',
  'costOfGoods',
  'marginPercent',
  'profitPercent',
  'averageCostMinor',
  'unitCostMinor',
  'totalCostMinor',
};

dynamic withoutCost(dynamic v) => switch (v) {
  Map m => {
    for (final e in m.entries)
      if (!costFields.contains(e.key)) e.key: withoutCost(e.value),
  },
  List l => l.map(withoutCost).toList(),
  _ => v,
};

Map<String, dynamic> _cost(Map<String, dynamic> j, bool cost) =>
    cost ? j : Map<String, dynamic>.from(withoutCost(j));

// ---- Auth and shop -------------------------------------------------------------------------

/// The user inside POST /auth/login's `data` (auth.controller.ts login): permissions already
/// expanded.
Map<String, Object?> userJson({
  String id = 'u1',
  String clientId = 'shop-1',
  String name = 'Asha Rao',
  String email = 'asha@shop.in',
  List<String>? roles,
  Iterable<String> permissions = const ['*'],
}) => {
  'id': id,
  'clientId': clientId,
  'name': name,
  'email': email,
  // SUPER_ADMIN alone makes an owner (AuthUser.isOwner), so only with `*`.
  'roles': roles ?? [permissions.contains('*') ? 'SUPER_ADMIN' : 'STAFF'],
  'permissions': permissions.toList(),
};

/// POST /auth/login, signed in (also sets the httpOnly `token` cookie).
Map<String, Object?> loginJson({Map<String, Object?>? user}) =>
    ok({'user': user ?? userJson()});

/// POST /auth/login when the email + password match accounts in more than one shop: a 200.
Map<String, Object?> workspaceChoiceJson({
  List<String> clientIds = const ['shop-1', 'shop-2'],
}) => {
  'success': false,
  'requiresWorkspaceSelection': true,
  'message':
      'This email is used in more than one workspace. Choose which one to sign into.',
  'workspaces': [
    for (final id in clientIds) {'clientId': id},
  ],
};

/// GET /auth/session, signed in: `user` and `client` at the top level, no `data`.
Map<String, Object?> sessionJson({Map<String, Object?>? user}) {
  final u = Map.of(user ?? userJson())..remove('clientId');
  return {
    'success': true,
    'authenticated': true,
    'user': {...u, 'tourSeenAt': '2026-09-01T00:00:00.000Z'},
    'client': {'id': (user ?? userJson())['clientId']},
    'modules': ['inventory'],
  };
}

/// GET /branding.
Map<String, Object?> brandingJson({
  String? businessName = 'Lakshmi Silks',
  String? logoUrl,
  String? businessAddress = '12 MG Road, Vijayawada',
  String? businessPhone = '+91 86600 12345',
}) => ok({
  'businessName': businessName,
  'logoUrl': logoUrl,
  'businessAddress': businessAddress,
  'businessPhone': businessPhone,
});

/// One stock location (Prisma `Location`).
Map<String, Object?> locationJson(
  String id, {
  String? code,
  String? name,
  String type = 'STORE',
  bool active = true,
}) => {
  'id': id,
  'code': code ?? id.toUpperCase(),
  'name': name ?? 'Store $id',
  'type': type,
  'active': active,
};

/// GET /locations: a bare array. MAIN-STORE (the default), a second store, the ONLINE store
/// and a switched-off one.
List<Map<String, Object?>> locationsJson() => [
  locationJson('loc-main', code: 'MAIN-STORE', name: 'Main Store'),
  locationJson('loc-branch', code: 'CHIRALA', name: 'Chirala Branch'),
  locationJson('loc-online', code: 'ONLINE', name: 'Online', type: 'ONLINE'),
  locationJson('loc-old', code: 'OLD', name: 'Old Godown', active: false),
];

// ---- Products ------------------------------------------------------------------------------

/// A row of GET /products (product.service list) or GET /products/:id.
Map<String, Object?> productJson(
  String id, {
  String title = 'Banarasi Saree',
  String basePrice = '1499.00',
  String category = 'WOMEN',
  String productType = 'UNSTITCHED',
  String status = 'ACTIVE',
  int variantCount = 2,
  int totalUnits = 7,
  int lowStockVariants = 1,
}) => {
  'id': id,
  'title': title,
  'productCode': 'SE-$id',
  'category': category,
  'productType': productType,
  'fabric': 'Silk',
  'basePrice': basePrice,
  'status': status,
  'coverImageUrl': null,
  'createdAt': '2026-09-01T09:00:00.000Z',
  'variantSummary': {
    'variantCount': variantCount,
    'totalUnits': totalUnits,
    'lowStockVariants': lowStockVariants,
  },
};

/// GET /products: `{success, data, meta: {page, limit, total, pages}}`.
Map<String, Object?> productListJson(
  List<Map<String, Object?>> products, {
  int page = 1,
  int limit = 20,
  int? total,
}) => {
  'success': true,
  'data': products,
  'meta': _pagination(page, limit, total ?? products.length),
};

/// A row of GET /products/:id/variants: Prisma Variant with per-location `stocks` (summed into
/// `totalQuantity`). Costs are Decimal strings; [cost] false strips them as for a role without
/// cost:view.
Map<String, dynamic> variantJson(
  String id, {
  String colour = 'Red',
  String size = 'M',
  int quantity = 5,
  int reorderLevel = 2,
  String? sellingPrice = '1499.00',
  String? costPrice = '850.00',
  String? averageCost = '841.50',
  bool cost = true,
}) => _cost({
  'id': id,
  'sku': 'SKU-$id',
  'variantCode': 'V-$id',
  'barcode': '890$id',
  'size': size,
  'colorName': colour,
  'hexCode': '#B91C1C',
  'reorderLevel': reorderLevel,
  'sellingPrice': sellingPrice,
  'costPrice': costPrice,
  'averageCost': averageCost,
  'totalQuantity': quantity,
  'stocks': [
    {'locationId': 'loc-main', 'quantity': quantity, 'reservedQty': 0},
  ],
}, cost);

// ---- Inventory -----------------------------------------------------------------------------

/// A row of GET /inventory/variants as inventory.service builds it (a hand-built DTO: numbers).
Map<String, dynamic> stockRow(
  String variantId, {
  String title = 'Saree',
  int quantity = 5,
  bool cost = false,
}) => _cost({
  'variantId': variantId,
  'productId': 'p-$variantId',
  'sku': 'SKU-$variantId',
  'productTitle': title,
  'category': 'WOMEN',
  'quantity': quantity,
  'averageCost': 1200,
  'inventoryValue': 1200 * quantity,
  'costBasis': 'AVERAGE',
  'costIsEstimate': false,
  'status': 'ACTIVE',
  'inventoryStatus': quantity > 0 ? 'HEALTHY' : 'OUT_OF_STOCK',
  'reorderLevel': 2,
  'lowStockThreshold': 2,
  'updatedAt': '2026-10-01T10:00:00.000Z',
}, cost);

/// A compact movement row (dashboard recent activity).
Map<String, dynamic> movementJson(String id, int quantity, DateTime at) => {
  'id': id,
  'type': quantity > 0 ? 'IN' : 'OUT',
  'quantity': quantity,
  'productTitle': 'Saree',
  'sku': 'SKU-$id',
  'createdAt': at.toIso8601String(),
};

/// A row of GET /inventory/transactions (inventory.repository getTransactions): the Prisma row
/// with its variant and product, and the performer's name in `createdBy`.
Map<String, dynamic> transactionJson(
  String id, {
  String type = 'IN',
  String reason = 'PURCHASE_RECEIPT',
  int quantity = 5,
  int balanceAfter = 12,
  String createdAt = '2026-10-12T05:30:00.000Z',
}) => {
  'id': id,
  'clientId': 'shop-1',
  'variantId': 'v-$id',
  'locationId': 'loc-main',
  'type': type,
  'reason': reason,
  'quantity': quantity,
  'balanceAfter': balanceAfter,
  'referenceType': 'PURCHASE_ORDER',
  'reference': 'PO-7',
  'notes': null,
  'createdBy': 'Asha',
  'createdAt': createdAt,
  'variant': {
    'id': 'v-$id',
    'sku': 'SKU-$id',
    'product': {'title': 'Banarasi Saree', 'productCode': 'SE-1'},
  },
};

/// GET /inventory/transactions: `{success, data: {data, pagination}}`.
Map<String, Object?> transactionsJson(
  List<Object?> rows, {
  int page = 1,
  int limit = 50,
}) => ok({'data': rows, 'pagination': _pagination(page, limit, rows.length)});

/// One row of GET /inventory/alerts -> data.alerts (inventory-alert.controller.ts).
Map<String, Object?> alertJson(
  String id, {
  String type = 'LOW_STOCK',
  int quantity = 1,
  int reorderLevel = 5,
  String? productId,
}) => {
  'id': id,
  'type': type,
  'severity': type == 'OUT_OF_STOCK' ? 'CRITICAL' : 'WARNING',
  'title': 'Low stock',
  'message': 'Only $quantity left',
  'variantId': 'v-$id',
  'variantName': 'Saree $id',
  'productTitle': 'Saree $id',
  'productId': productId ?? 'p-$id',
  'sku': 'SKU-$id',
  'colorName': 'Red',
  'size': 'M',
  'quantity': quantity,
  'reorderLevel': reorderLevel,
  'currentQuantity': quantity,
  'threshold': reorderLevel,
  'locationId': 'loc-main',
  'locationName': 'Main Store',
  'isRead': false,
  'isResolved': false,
  'isPinned': false,
  'createdAt': '2026-10-12T05:30:00.000Z',
};

/// GET /inventory/alerts.
Map<String, Object?> alertsJson(List<Map<String, Object?>> alerts) =>
    ok({'alerts': alerts, 'unreadCount': alerts.length});

// ---- Sales orders (raw, no envelope) -------------------------------------------------------

/// The payment summary an order carries (sales-order payment summary).
Map<String, Object?> paymentJson({
  num paid = 3000,
  num due = 98,
  String status = 'PART_PAID',
}) => {
  'paid': paid,
  'refunded': 0,
  'due': due,
  'writtenOff': 0,
  'status': status,
};

/// A row of GET /sales-orders: a raw array, Decimals as strings.
Map<String, Object?> orderJson(
  String id, {
  String customer = 'Priya Sharma',
  String status = 'CONFIRMED',
  String total = '3098.00',
  int pieces = 2,
  bool atCounter = false,
  String? sourceSystem = 'SCALEEZY_POS',
  String channel = 'POS',
  Map<String, Object?>? payment,
  String createdAt = '2026-10-12T10:35:00.000Z',
}) => {
  'id': id,
  'orderNumber': 'SO-$id',
  'status': status,
  'total': total,
  'customerName': customer,
  'customer': {'name': customer, 'phone': '+919848022338'},
  'sourceSystem': sourceSystem,
  'channel': channel,
  'atCounter': atCounter,
  'createdBy': {'id': 'u1', 'name': 'Asha'},
  'location': {'id': 'loc-main', 'name': 'Main Store'},
  'items': [
    {'quantity': pieces},
  ],
  'payment': payment ?? paymentJson(),
  'createdAt': createdAt,
};

/// GET /sales-orders/:id: raw object with lines, payments and the payment summary.
Map<String, Object?> orderDetailJson(
  String id, {
  String status = 'CONFIRMED',
  bool atCounter = false,
}) => {
  ...orderJson(id, status: status, atCounter: atCounter, total: '2998.00'),
  'subtotal': '2998.00',
  'discountAmount': '0.00',
  'taxAmount': '0.00',
  'shippingAmount': '0.00',
  'items': [
    {
      'id': 'i1',
      'variantId': 'v1',
      'quantity': 2,
      'fulfilledQty': 0,
      'heldQty': 2,
      'unitPrice': '1499.00',
      'totalPrice': '2998.00',
      'variant': {
        'sku': 'SKU-1',
        'size': 'M',
        'colorName': 'Red',
        'product': {'title': 'Banarasi Saree'},
      },
    },
  ],
  'payments': [
    {
      'id': 'p1',
      'kind': 'PAYMENT',
      'method': 'CASH',
      'amount': '3000.00',
      'cashReceived': '3000.00',
      'changeGiven': '2.00',
      'reference': null,
      'receivedAt': '2026-10-12T10:35:00.000Z',
      'receivedBy': {'name': 'Asha'},
    },
  ],
};

/// A counter bill as counter-sale.service.ts getSale() returns it (the `data` of
/// GET /counter-sales/:orderId/receipt): a 5% saree with an offer, 18% stitching (a SAC code),
/// paid part in cash and part by UPI, 98 still due.
Map<String, dynamic> receiptJson({
  bool atCounter = true,
  String? phone = '+91 98480 22338',
}) => {
  'id': 'o1',
  'orderNumber': 'SO-0042',
  'status': 'DISPATCHED',
  'channel': 'POS',
  'handover': 'TAKEN_NOW',
  'atCounter': atCounter,
  'createdAt': '2026-10-12T10:35:00.000Z',
  'soldBy': 'Asha',
  'store': {
    'id': 'l1',
    'name': 'Main Store',
    'address': '12 MG Road, Vijayawada',
    'phone': '+91 86600 12345',
  },
  'customer': {
    'id': 'c1',
    'name': 'Priya Sharma',
    'code': 'CUS-0007',
    'phone': phone,
    'phoneMasked': phone == null ? null : '••••2338',
  },
  'items': [
    {
      'id': 'i1',
      'variantId': 'v1',
      'title': 'Banarasi Saree',
      'sku': 'SAR-RED-F',
      'colorName': 'Red',
      'size': 'Free',
      'quantity': 2,
      'fulfilledQty': 2,
      'listUnitPrice': 1499,
      'lineDiscount': 0,
      'allocatedDiscount': 149.9,
      'unitPrice': 1424.05,
      'totalPrice': 2848.1,
      'priceSource': 'LIST',
      'hsnCode': '5007',
      'taxRateBps': 500,
      'discounts': [
        {'title': 'Festive 5%', 'source': 'OFFER', 'amount': 149.9},
      ],
    },
    {
      'id': 'i2',
      'variantId': 'v2',
      'title': 'Stitching',
      'sku': 'SRV-STITCH',
      'colorName': null,
      'size': null,
      'quantity': 1,
      'fulfilledQty': 1,
      'listUnitPrice': 250,
      'lineDiscount': null,
      'allocatedDiscount': null,
      'unitPrice': 250,
      'totalPrice': 250,
      'priceSource': 'LIST',
      'hsnCode': '998821',
      'taxRateBps': 1800,
      'discounts': [],
    },
  ],
  'discounts': [
    {
      'id': 'd1',
      'source': 'OFFER',
      'title': 'Festive 5%',
      'amount': 149.9,
      'code': null,
    },
  ],
  'subtotal': 3248,
  'discountAmount': 149.9,
  'taxAmount': 0,
  'shippingAmount': 0,
  'roundOff': -0.1,
  'total': 3098,
  'payments': [
    {
      'id': 'p1',
      'kind': 'PAYMENT',
      'method': 'CASH',
      'amount': 2000,
      'cashReceived': 2000,
      'changeGiven': 0,
      'reference': null,
      'receivedAt': '2026-10-12T10:35:00.000Z',
      'receivedBy': 'Asha',
    },
    {
      'id': 'p2',
      'kind': 'PAYMENT',
      'method': 'UPI',
      'amount': 1000,
      'cashReceived': null,
      'changeGiven': null,
      'reference': 'UTR123',
      'receivedAt': '2026-10-12T10:35:00.000Z',
      'receivedBy': 'Asha',
    },
  ],
  'payment': {
    'paid': 3000,
    'refunded': 0,
    'due': 98,
    'writtenOff': 0,
    'status': 'PART_PAID',
  },
  'writtenOff': null,
  'gst': [
    {
      'rateBps': 500,
      'taxable': 2712.48,
      'cgst': 67.81,
      'sgst': 67.81,
      'igst': 0,
    },
    {
      'rateBps': 1800,
      'taxable': 211.86,
      'cgst': 19.07,
      'sgst': 19.07,
      'igst': 0,
    },
  ],
  'buyer': null,
  'shop': {
    'name': 'Lakshmi Silks',
    'logoUrl': null,
    'address': '12 MG Road, Vijayawada',
    'phone': '+91 86600 12345',
    'email': null,
    'gstNumber': '37ABCDE1234F1Z5',
    'receiptFooter': 'No exchange without bill.',
  },
};

// ---- Customers -----------------------------------------------------------------------------

/// A row of GET /customers or GET /customers/:id (Prisma Customer).
Map<String, Object?> customerJson(
  String id, {
  String name = 'Priya Sharma',
  String? phone = '+919848022338',
  String? email,
}) => {
  'id': id,
  'customerCode': 'CUS-$id',
  'name': name,
  'phone': phone,
  'email': email,
  'status': 'ACTIVE',
  'tags': [],
  'createdAt': '2026-09-01T09:00:00.000Z',
};

/// 409 body pieces from customer.controller.ts `taken`: pass as `conflict(..., fields: ...)`.
Map<String, Object?> phoneTakenFields(
  String id, {
  String name = 'Priya Sharma',
}) => {
  'existingCustomerId': id,
  'existingCustomerName': name,
  'existingCustomerCode': 'CUS-$id',
};

// ---- Buying --------------------------------------------------------------------------------

/// A row of GET /suppliers (Prisma Supplier + `_count`).
Map<String, Object?> supplierJson(
  String id, {
  String name = 'Weavers Co',
  String? phone = '9800000000',
  bool active = true,
}) => {
  'id': id,
  'supplierCode': 'SUP-$id',
  'name': name,
  'phone': phone,
  'isActive': active,
  '_count': {'purchaseOrders': 2},
};

/// A purchase order line (GET /purchase-orders/:id items).
Map<String, Object?> poLineJson(
  String id, {
  int ordered = 10,
  int received = 0,
  String? unitPrice = '850.50',
}) => {
  'id': id,
  'variantId': 'v-$id',
  'productTitle': 'Saree $id',
  'sku': 'SKU-$id',
  'barcode': 'BC-$id',
  'color': 'Red',
  'size': 'M',
  'orderedQty': ordered,
  'receivedQty': received,
  'unitPrice': ?unitPrice,
};

/// A row of GET /purchase-orders, or with [items] the order GET /purchase-orders/:id answers.
Map<String, Object?> purchaseOrderJson(
  String id, {
  String status = 'SENT',
  String supplier = 'Weavers Co',
  List<Map<String, Object?>>? items,
  Map<String, Object?>? location,
}) => {
  'id': id,
  'poNumber': 'PO-$id',
  'status': status,
  'totalAmount': '8505.00',
  'expectedDeliveryDate': '2026-10-20T00:00:00.000Z',
  'createdAt': '2026-09-01T00:00:00.000Z',
  'notes': null,
  'supplier': {'name': supplier, 'phone': '9800000000'},
  'location':
      location ??
      {
        'id': 'loc-main',
        'name': 'Main Store',
        'code': 'MAIN-STORE',
        'active': true,
      },
  if (items == null) '_count': {'items': 1} else 'items': items,
};

/// POST /purchase-orders/:id/receive: `data` is the order; the receipt rides beside it.
/// [duplicate] is the answer to a repeated requestKey.
Map<String, Object?> receiveAnswerJson({
  String receiptNumber = 'GRN-0007',
  bool duplicate = false,
}) => {
  'success': true,
  'data': purchaseOrderJson('po1', status: 'PARTIALLY_RECEIVED', items: []),
  'receipt': {'id': 'r1', 'receiptNumber': receiptNumber},
  if (duplicate) 'duplicate': true,
};

// ---- Shelves -------------------------------------------------------------------------------

/// A shelf (or rack, with [children]) in GET /shelves/locations/:id/spots.
Map<String, Object?> spotJson(
  String id, {
  String kind = 'SHELF',
  int pieces = 0,
  List<Map<String, Object?>> children = const [],
}) => {
  'id': id,
  'kind': kind,
  'code': id.toUpperCase(),
  'address': id.toUpperCase(),
  'name': null,
  'active': true,
  'pieces': pieces,
  'branchPieces':
      pieces +
      children.fold<int>(0, (a, c) => a + (c['branchPieces'] as int? ?? 0)),
  'children': children,
};

/// GET /shelves/locations/:id/spots: one rack R1 with two shelves.
Map<String, Object?> shelfTreeJson({String locationId = 'loc-main'}) => ok({
  'location': {'id': locationId, 'name': 'Main Store'},
  'count': 3,
  'pieces': {'total': 10, 'onShelves': 7, 'notShelved': 3},
  'spots': [
    spotJson(
      'r1',
      kind: 'RACK',
      children: [spotJson('r1-s1', pieces: 4), spotJson('r1-s2', pieces: 3)],
    ),
  ],
});

/// A piece on a shelf (spot contents and not-shelved rows).
Map<String, Object?> shelfItemJson(
  String variantId, {
  String title = 'Banarasi Saree',
  int quantity = 2,
}) => {
  'variantId': variantId,
  'productId': 'p-$variantId',
  'title': title,
  'sku': 'SKU-$variantId',
  'barcode': '890$variantId',
  'colorName': 'Red',
  'hexCode': '#B91C1C',
  'size': 'M',
  'imageUrl': null,
  'archived': false,
  'quantity': quantity,
};

/// GET /shelves/spots/:id or /shelves/spots/scan.
Map<String, Object?> spotContentsJson(
  String spotId, {
  String locationId = 'loc-main',
  List<Map<String, Object?>>? items,
}) {
  final rows = items ?? [shelfItemJson('v1')];
  return ok({
    'spot': {
      'id': spotId,
      'address': spotId.toUpperCase(),
      'name': null,
      'kind': 'SHELF',
      'labelCode': 'K7Q2M9XA',
      'capacity': null,
      'holdsStock': true,
      'location': {'id': locationId, 'name': 'Main Store'},
    },
    'total': rows.fold<int>(0, (a, i) => a + (i['quantity'] as int)),
    'overCapacity': false,
    'items': rows,
  });
}

/// GET /shelves/find?q=: where each matching piece is, per store.
Map<String, Object?> findJson({String variantId = 'v1'}) => ok({
  'items': [
    {
      'variantId': variantId,
      'productId': 'p-$variantId',
      'title': 'Banarasi Saree',
      'sku': 'SKU-$variantId',
      'colorName': 'Red',
      'size': null,
      'places': [
        {
          'locationId': 'loc-main',
          'location': 'Main Store',
          'total': 5,
          'held': 1,
          'usesShelves': true,
          'notShelved': 2,
          'shelves': [
            {
              'spotId': 'r1-s1',
              'address': 'R1-S1',
              'colour': '#ff0000',
              'isShopFloor': true,
              'quantity': 3,
            },
          ],
        },
      ],
    },
  ],
});

/// GET /shelves/locations/:id/not-shelved.
Map<String, Object?> notShelvedJson(List<Map<String, Object?>> rows) =>
    ok({'items': rows});

/// A not-shelved row: the piece, its stock and how much of it is not on a shelf.
Map<String, Object?> notShelvedRowJson(
  String variantId, {
  int notShelved = 2,
}) => {
  ...shelfItemJson(variantId, quantity: notShelved),
  'total': notShelved + 3,
  'notShelved': notShelved,
};

// ---- Picking and transfers -----------------------------------------------------------------

/// A row of GET /shelves/pick/orders -> data.orders.
Map<String, Object?> pickOrderJson(
  String id, {
  int pieces = 2,
  String status = 'CONFIRMED',
}) => {
  'id': id,
  'orderNumber': 'SO-$id',
  'channel': 'POS',
  'source': null,
  'handover': 'KEEP_FOR_CUSTOMER',
  'status': status,
  'createdAt': '2026-10-10T05:30:00.000Z',
  'customer': 'Asha',
  'lines': 1,
  'pieces': pieces,
};

/// GET /shelves/pick/orders?locationId=.
Map<String, Object?> pickOrdersJson(List<Map<String, Object?>> orders) => ok({
  'location': {'id': 'loc-main', 'name': 'Main Store'},
  'orders': orders,
});

/// One pick of an order line.
Map<String, Object?> pickJson(
  String orderId,
  String lineId,
  int quantity, {
  String variantId = 'v1',
}) => {
  'orderId': orderId,
  'orderNumber': 'SO-$orderId',
  'salesOrderItemId': lineId,
  'variantId': variantId,
  'quantity': quantity,
  'item': {
    'variantId': variantId,
    'title': 'Banarasi silk',
    'sku': 'BAN-RED-M',
    'code': 'V0042',
    'barcode': '8901234',
    'colorName': 'Red',
    'hexCode': '#B91C1C',
    'size': 'M',
    'imageUrl': null,
  },
};

/// GET /shelves/pick/list?locationId=&orderIds=: one stop on a shelf, one piece not shelved.
Map<String, Object?> pickListJson({String orderId = 'so1'}) => ok({
  'location': {'id': 'loc-main', 'name': 'Main Store'},
  'orders': [
    {
      'id': orderId,
      'orderNumber': 'SO-$orderId',
      'customer': 'Asha',
      'channel': 'POS',
    },
  ],
  'stops': [
    {
      'spotId': 'r1-s1',
      'address': 'R1-S1',
      'name': 'Silk top',
      'colour': '#22C55E',
      'isShopFloor': true,
      'labelCode': 'K7Q2M9XA',
      'picks': [pickJson(orderId, 'i1', 2)],
    },
  ],
  'notShelved': [pickJson(orderId, 'i2', 1, variantId: 'v2')],
  'short': [],
  'pieces': 3,
});

/// POST /dispatches: the dispatch, raw.
Map<String, Object?> dispatchJson({String id = 'd1'}) => {
  'id': id,
  'dispatchNumber': 'DSP-0007',
  'status': 'DISPATCHED',
};

/// POST /inventory-transfers (inventory-transfer.controller): `{success, transferredItems}`.
Map<String, Object?> transferJson({int items = 1}) => {
  'success': true,
  'transferredItems': items,
};

// ---- Stock counts --------------------------------------------------------------------------

/// A count as `GET /stock-counts` lists it (Prisma row + `_count`).
Map<String, Object?> countJson(
  String id, {
  String name = 'October 2026 Full Count',
  String status = 'IN_PROGRESS',
  String? locationId = 'L1',
  int items = 3,
  int? matched,
  int? adjusted,
  String? accuracy,
}) => {
  'id': id,
  'clientId': 'shop-1',
  'name': name,
  'status': status,
  'locationId': locationId,
  'startedAt': status == 'DRAFT' ? null : '2026-10-01T09:30:00.000Z',
  'completedAt': null,
  'createdBy': 'Asha',
  'completedBy': null,
  'totalItems': matched == null ? null : items,
  'matchedItems': matched,
  'adjustedItems': adjusted,
  'accuracy': accuracy,
  'createdAt': '2026-10-01T09:00:00.000Z',
  'updatedAt': '2026-10-01T09:30:00.000Z',
  '_count': {'items': items},
};

/// A line as `GET /stock-counts/:id` answers it, with the variant's stock at the count's store.
Map<String, Object?> lineJson(
  String id, {
  String title = 'Silk Saree',
  int expected = 5,
  int? counted,
  int? onHand,
  String? barcode,
}) => {
  'id': id,
  'stockCountId': 'c1',
  'variantId': 'v-$id',
  'sku': 'SKU-$id',
  'variantCode': 'VC-$id',
  'barcode': barcode ?? '8901$id',
  'expectedQty': expected,
  'countedQty': counted,
  'updatedAt': '2026-10-01T09:00:00.000Z',
  'variant': {
    'stocks': [
      {'locationId': 'L1', 'quantity': onHand ?? expected},
    ],
    'product': {'title': title},
    'quantity': onHand ?? expected,
  },
};

/// GET /stock-counts/:id: the count with its lines.
Map<String, Object?> countDetailJson({
  String status = 'IN_PROGRESS',
  List<Map<String, Object?>>? items,
}) => {
  ...countJson('c1', status: status),
  'items':
      items ??
      [
        lineJson('a', title: 'Cotton Kurta', expected: 4),
        lineJson('b', title: 'Silk Saree', expected: 10, counted: 10),
        lineJson('c', title: 'Linen Shirt', expected: 2, counted: 3),
      ],
};

// ---- Team ----------------------------------------------------------------------------------

/// A row of GET /team/members.
Map<String, Object?> memberJson(
  String id, {
  String name = 'Meena',
  String status = 'ACTIVE',
  String role = 'STORE_MANAGER',
}) => {
  'id': id,
  'name': name,
  'email': '$id@shop.in',
  'status': status,
  'roles': [
    {
      'role': {'id': 'r-$role', 'name': role},
    },
  ],
  'lastActiveAt': '2026-10-12T05:30:00.000Z',
};

// ---- Day book ------------------------------------------------------------------------------

/// One day as daybook.service.ts build() returns it (the `data` of GET /daybook): sold 4,
/// one piece came back, cash and UPI at the counter, count balanced but value re-valued.
Map<String, dynamic> dayBookJson({
  String date = '2026-10-12',
  bool inProgress = true,
  bool cost = true,
}) => _cost({
  'date': date,
  'money': {
    'taken': {
      'CASH': {'amount': 4200, 'count': 3},
      'UPI': {'amount': 6830.5, 'count': 2},
      'CREDIT': {'amount': 300, 'count': 1},
    },
    'paidBack': {
      'CASH': {'amount': 1200, 'count': 1},
    },
    'cashInDrawer': 3000,
  },
  'range': null,
  'days': null,
  'timezone': 'Asia/Kolkata',
  'businessName': 'Lakshmi Silks',
  'inProgress': inProgress,
  'quiet': false,
  'opening': {
    'units': 120,
    'value': 180000,
    'source': 'derived',
    'asOf': '2026-10-11T18:30:00.000Z',
  },
  'closing': {'units': 183, 'value': 273320},
  'measuredClosing': {'units': 183, 'value': 276407.57},
  'balanced': true,
  'valueMatches': false,
  'valueGap': 3087.57,
  'measuredClosingValue': 276407.57,
  'stockIn': {
    'lines': [
      {
        'reason': 'PURCHASE_RECEIPT',
        'label': 'Purchase received',
        'units': 66,
        'value': 99000,
      },
      {
        'reason': 'CUSTOMER_RETURN',
        'label': 'Customer returns',
        'units': 1,
        'value': 1500,
      },
    ],
    'totalUnits': 67,
    'totalValue': 100500,
  },
  'stockOut': {
    'lines': [
      {
        'reason': 'SALE',
        'label': 'Sold and dispatched',
        'units': 4,
        'value': 7180,
      },
    ],
    'totalUnits': 4,
    'totalValue': 7180,
  },
  'transfers': {'unitsMoved': 0},
  'sales': {
    'dispatchCount': 2,
    'unitsDispatched': 4,
    'revenue': 11530,
    'gstCollected': 549.06,
    'returns': {
      'count': 1,
      'units': 1,
      'value': 2240,
      'gst': 106.67,
      'cost': 1500,
    },
    'netSales': 8847.61,
    'costOfGoods': 7180,
    'netCost': 5680,
    'grossProfit': 3167.61,
    'unitsSoldWithoutCost': 0,
    'orders': [
      {
        'dispatchNumber': 'DSP-0007',
        'orderNumber': 'SO-0042',
        'customer': 'Priya Sharma',
        'units': 3,
        'value': 8998,
        'status': 'DISPATCHED',
      },
      {
        'dispatchNumber': 'DSP-0008',
        'orderNumber': 'SO-0043',
        'customer': null,
        'units': 1,
        'value': 2532,
        'status': 'DISPATCHED',
      },
    ],
  },
  'byLocation': [
    {
      'locationId': 'l1',
      'name': 'Main Store',
      'code': 'MS',
      'unitsIn': 67,
      'unitsOut': 4,
      'netChange': 63,
      'transferIn': 0,
      'transferOut': 0,
      'movementCount': 5,
    },
  ],
  'topMovers': [
    {
      'sku': 'SAR-RED-M',
      'title': 'Banarasi Saree',
      'unitsOut': 3,
      'unitsIn': 0,
    },
  ],
  'adjustments': [
    {
      'sku': 'KUR-BLU-L',
      'title': 'Cotton Kurta',
      'units': -1,
      'reason': 'Manual corrections',
      'by': 'Asha',
      'at': '2026-10-12T06:00:00.000Z',
    },
  ],
  'alsoToday': {
    'purchaseOrdersRaised': 1,
    'purchaseOrdersReceived': 2,
    'newVariantsAdded': 5,
  },
}, cost);
