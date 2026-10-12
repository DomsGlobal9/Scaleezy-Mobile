import 'dart:math';

import '../models/inventory_models.dart';
import '../models/module_models.dart';
import 'api_client.dart';

/// Endpoints behind the "More" tab. Permissions noted per call.
class ModuleRepository {
  ModuleRepository([ApiClient? client]) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  static List<Map<String, dynamic>> _list(dynamic v) => v is List
      ? v.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
      : const [];
  static Map<String, dynamic> _map(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : const {};

  // ---- Shelves ----------------------------------------------------------------------------------

  /// shelf:view
  Future<ShelfTree> shelfTree(String locationId) async => ShelfTree.fromJson(
    _map(dataOf(await _api.get('/shelves/locations/$locationId/spots'))),
  );

  /// shelf:view. [code] is what the shelf label's barcode reads.
  Future<SpotContents> scanSpot(String code, {String? locationId}) async =>
      SpotContents.fromJson(
        _map(
          dataOf(
            await _api.get(
              '/shelves/spots/scan',
              query: {'code': code.trim(), 'locationId': locationId},
            ),
          ),
        ),
      );

  /// shelf:view
  Future<SpotContents> spot(String spotId) async => SpotContents.fromJson(
    _map(dataOf(await _api.get('/shelves/spots/$spotId'))),
  );

  /// shelf:view. Where a piece is, searched by name, SKU or barcode.
  Future<List<WhereItem>> findOnShelves(String q, {String? locationId}) async {
    final data = _map(
      dataOf(
        await _api.get(
          '/shelves/find',
          query: {'q': q.trim(), 'locationId': locationId},
        ),
      ),
    );
    return _list(data['items']).map(WhereItem.fromJson).toList();
  }

  /// shelf:view
  Future<List<NotShelvedItem>> notShelved(String locationId) async {
    final data = _map(
      dataOf(await _api.get('/shelves/locations/$locationId/not-shelved')),
    );
    return _list(data['items']).map(NotShelvedItem.fromJson).toList();
  }

  /// shelf:putaway. Pieces not on any shelf yet go onto [spotId].
  /// Moves pieces between shelves only; the location's stock count does not change.
  Future<String?> putAway({
    required String locationId,
    required String variantId,
    required String spotId,
    required int quantity,
  }) async {
    final body = await _api.post(
      '/shelves/putaway',
      body: {
        'locationId': locationId,
        'variantId': variantId,
        'spotId': spotId,
        'quantity': quantity,
      },
    );
    return _map(dataOf(body))['warning'] as String?;
  }

  /// shelf:putaway. From one shelf to another (either may be null, not both).
  Future<String?> moveOnShelves({
    required String locationId,
    required String variantId,
    String? fromSpotId,
    String? toSpotId,
    required int quantity,
  }) async {
    final body = await _api.post(
      '/shelves/move',
      body: {
        'locationId': locationId,
        'variantId': variantId,
        'fromSpotId': ?fromSpotId,
        'toSpotId': ?toSpotId,
        'quantity': quantity,
      },
    );
    return _map(dataOf(body))['warning'] as String?;
  }

  // ---- Customers --------------------------------------------------------------------------------

  /// customer:view. A bare array.
  Future<List<Customer>> customers({String? search}) async => _list(
    dataOf(await _api.get('/customers', query: {'search': search?.trim()})),
  ).map(Customer.fromJson).toList();

  /// customer:view. Includes recent orders.
  Future<Customer> customer(String id) async =>
      Customer.fromJson(_map(dataOf(await _api.get('/customers/$id'))));

  /// customer:view. Null when no customer has that number.
  Future<Customer?> customerByPhone(String phone) async {
    final data = dataOf(
      await _api.get(
        '/customers/by-phone/${Uri.encodeComponent(phone.trim())}',
      ),
    );
    return data is Map && data['id'] != null
        ? Customer.fromJson(Map<String, dynamic>.from(data))
        : null;
  }

  /// customer:create
  Future<Customer> createCustomer({
    required String name,
    required String phone,
    String? email,
  }) async => Customer.fromJson(
    _map(
      dataOf(
        await _api.post(
          '/customers',
          body: {
            'name': name.trim(),
            'phone': phone.trim(),
            if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
          },
        ),
      ),
    ),
  );

  /// customer:update
  Future<Customer> updateCustomer(
    String id, {
    String? name,
    String? phone,
    String? email,
  }) async => Customer.fromJson(
    _map(
      dataOf(
        await _api.patch(
          '/customers/$id',
          body: {
            'name': ?name?.trim(),
            'phone': ?phone?.trim(),
            if (email != null)
              'email': email.trim().isEmpty ? null : email.trim(),
          },
        ),
      ),
    ),
  );

  // ---- Suppliers & purchase orders --------------------------------------------------------------

  /// supplier:view
  Future<List<Supplier>> suppliers() async => _list(
    dataOf(await _api.get('/suppliers')),
  ).map(Supplier.fromJson).toList();

  /// purchase_order:view
  Future<List<PurchaseOrderSummary>> purchaseOrders() async => _list(
    dataOf(await _api.get('/purchase-orders')),
  ).map(PurchaseOrderSummary.fromJson).toList();

  /// purchase_order:view
  Future<PurchaseOrderDetail> purchaseOrder(String id) async =>
      PurchaseOrderDetail.fromJson(
        _map(dataOf(await _api.get('/purchase-orders/$id'))),
      );

  /// purchase_order:receive. Adds the received pieces to stock. [requestKey] makes a retried
  /// submit (a timeout on a slow line) count once instead of twice.
  Future<void> receivePurchaseOrder(
    String id, {
    required Map<String, int> quantities, // poItemId -> pieces
    required String receivedByName,
    String? supplierReference,
    String? notes,
    required String requestKey,
  }) => _api.post(
    '/purchase-orders/$id/receive',
    body: {
      'receipts': [
        for (final e in quantities.entries)
          if (e.value > 0) {'poItemId': e.key, 'quantityReceived': e.value},
      ],
      'receivedByName': receivedByName.trim(),
      if (supplierReference != null && supplierReference.trim().isNotEmpty)
        'supplierReference': supplierReference.trim(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      'requestKey': requestKey,
    },
  );

  static String newRequestKey() {
    final r = Random.secure();
    return List.generate(24, (_) => r.nextInt(36).toRadixString(36)).join();
  }

  // ---- Team & account ---------------------------------------------------------------------------

  /// admin:users
  Future<List<TeamMember>> team() async => _list(
    dataOf(await _api.get('/team/members')),
  ).map(TeamMember.fromJson).toList();

  Future<void> updateMyName(String name) =>
      _api.patch('/auth/me', body: {'name': name.trim()});

  Future<void> changeMyPassword(String currentPassword, String newPassword) =>
      _api.post(
        '/auth/me/password',
        body: {'currentPassword': currentPassword, 'newPassword': newPassword},
      );

  Future<void> signOutOtherDevices() =>
      _api.post('/auth/me/sign-out-other-devices');

  /// Account owner only.
  Future<Branding> updateShopDetails({
    String? businessAddress,
    String? businessPhone,
  }) async => Branding.fromJson(
    _map(
      dataOf(
        await _api.put(
          '/branding/details',
          body: {
            'businessAddress': businessAddress,
            'businessPhone': businessPhone,
          },
        ),
      ),
    ),
  );

  /// Account owner only.
  Future<Branding> updateShopName(String? name) async => Branding.fromJson(
    _map(
      dataOf(await _api.put('/branding/name', body: {'businessName': name})),
    ),
  );
}
