import '../models/inventory_models.dart';
import 'api_client.dart';

/// One method per backend endpoint the app uses. Paths are relative to [kApiBaseUrl].
class ApiRepository {
  ApiRepository([ApiClient? client]) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  static List<Map<String, dynamic>> _list(dynamic v) => v is List
      ? v.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
      : const [];

  static Map<String, dynamic> _map(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : const {};

  // ---- Shop ---------------------------------------------------------------------------------

  /// Any signed-in user. Name and logo the owner set for the shop; all fields may be null.
  Future<Branding> getBranding() async =>
      Branding.fromJson(_map(dataOf(await _api.get('/branding'))));

  /// dashboard:view. A bare array.
  Future<List<StockLocation>> getLocations() async => _list(
    dataOf(await _api.get('/locations')),
  ).map(StockLocation.fromJson).toList();

  // ---- Dashboard ----------------------------------------------------------------------------

  /// dashboard:view
  Future<DashboardSummary> getDashboardSummary() async =>
      DashboardSummary.fromJson(
        _map(dataOf(await _api.get('/dashboard/summary'))),
      );

  // ---- Products -----------------------------------------------------------------------------

  /// product:view. Answers `{success, data: [...], meta: {page, limit, total, pages}}`.
  Future<Paged<ProductItem>> getProducts({
    int page = 1,
    int limit = 20,
    String? search,
    String? category,
    String? status,
    String sortBy = 'createdAt',
    String order = 'desc',
  }) async {
    final body = _map(
      await _api.get(
        '/products',
        query: {
          'page': page,
          'limit': limit,
          'search': search?.trim(),
          'category': category,
          'status': status,
          'sortBy': sortBy,
          'order': order,
        },
      ),
    );
    final meta = _map(body['meta']);
    return Paged(
      items: _list(body['data']).map(ProductItem.fromJson).toList(),
      page: (meta['page'] as num?)?.toInt() ?? page,
      pages: (meta['pages'] as num?)?.toInt() ?? page,
      total: (meta['total'] as num?)?.toInt() ?? 0,
    );
  }

  /// product:view. Full variant rows with stock per location; /products/:id leaves them out.
  Future<List<VariantItem>> getProductVariants(String productId) async => _list(
    dataOf(await _api.get('/products/$productId/variants')),
  ).map(VariantItem.fromJson).toList();

  // ---- Barcode / SKU lookup -----------------------------------------------------------------

  /// product:view. A barcode, SKU or variant code matches exactly and returns just that
  /// variant; anything else falls back to a fuzzy search.
  Future<List<VariantItem>> searchVariants(
    String q, {
    int page = 1,
    int limit = 20,
  }) async {
    final data = _map(
      dataOf(
        await _api.get(
          '/variants/search',
          query: {'q': q.trim(), 'page': page, 'limit': limit},
        ),
      ),
    );
    return _list(data['items']).map(VariantItem.fromSearchJson).toList();
  }

  /// inventory:view. Variants that are tracked, not sold out, and at or under their reorder
  /// level -- the same rule behind the dashboard's criticalStockItems.
  Future<List<VariantItem>> getLowStockVariants({int limit = 5}) async {
    final data = _map(
      dataOf(
        await _api.get(
          '/inventory/variants',
          query: {
            'lowStock': 'true',
            'sortBy': 'quantity',
            'order': 'asc',
            'limit': limit,
          },
        ),
      ),
    );
    return _list(data['items']).map(VariantItem.fromInventoryJson).toList();
  }

  /// inventory:view. Newest first; no date filter exists, so callers bucket what comes back.
  /// Answers `{success, data: {data: [...], pagination}}`.
  Future<List<TransactionItem>> getTransactions({
    String? variantId,
    int limit = 50,
  }) async {
    final body = _map(
      dataOf(
        await _api.get(
          '/inventory/transactions',
          query: {'variantId': variantId, 'limit': limit},
        ),
      ),
    );
    return _list(body['data']).map(TransactionItem.fromJson).toList();
  }

  // ---- Stock movements ----------------------------------------------------------------------

  /// inventory:receive
  Future<void> stockIn({
    required String variantId,
    required int quantity,
    required String reason,
    double? unitCost,
    String? notes,
  }) => _api.post(
    '/inventory/stock-in',
    body: {
      'variantId': variantId,
      'quantity': quantity,
      'reason': reason,
      'unitCost': ?unitCost,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    },
  );

  /// inventory:adjust. Only DAMAGE, SAMPLE and RETURN_TO_VENDOR are accepted by hand --
  /// sales take stock off by themselves.
  Future<void> stockOut({
    required String variantId,
    required int quantity,
    required String reason,
    String? notes,
  }) => _api.post(
    '/inventory/stock-out',
    body: {
      'variantId': variantId,
      'quantity': quantity,
      'reason': reason,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    },
  );

  // ---- Sales orders -------------------------------------------------------------------------

  /// sales_order:view. This route answers a bare array, not `{success, data}`.
  Future<List<OrderItemSummary>> getOrders({
    String? status,
    String? search,
  }) async => _list(
    dataOf(
      await _api.get(
        '/sales-orders',
        query: {'status': status, 'search': search},
      ),
    ),
  ).map(OrderItemSummary.fromJson).toList();

  /// sales_order:view. Also a bare object.
  Future<OrderDetail> getOrder(String id) async =>
      OrderDetail.fromJson(_map(dataOf(await _api.get('/sales-orders/$id'))));
}
