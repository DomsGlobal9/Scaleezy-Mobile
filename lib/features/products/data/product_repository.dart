import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/network/api_endpoints.dart';
import 'package:scaleezy/core/utils/json_parse.dart';
import 'package:scaleezy/core/models/paged.dart';
import 'package:scaleezy/features/products/data/product_models.dart';

/// Products, their variants, and barcode / SKU lookup. Permissions noted per call.
class ProductRepository {
  ProductRepository([ApiClient? client]) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

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
    final body = asMap(
      await _api.get(
        ApiEndpoints.products,
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
    final meta = asMap(body['meta']);
    return Paged(
      items: asMaps(body['data']).map(ProductItem.fromJson).toList(),
      page: (meta['page'] as num?)?.toInt() ?? page,
      pages: (meta['pages'] as num?)?.toInt() ?? page,
      total: (meta['total'] as num?)?.toInt() ?? 0,
    );
  }

  /// product:view. Full variant rows with stock per location; /products/:id leaves them out.
  Future<List<VariantItem>> getProductVariants(String productId) async =>
      asMaps(
        dataOf(await _api.get(ApiEndpoints.productVariants(productId))),
      ).map(VariantItem.fromJson).toList();

  /// product:view. A barcode, SKU or variant code matches exactly and returns just that
  /// variant; anything else falls back to a fuzzy search.
  Future<List<VariantItem>> searchVariants(
    String q, {
    int page = 1,
    int limit = 20,
  }) async {
    final data = asMap(
      dataOf(
        await _api.get(
          ApiEndpoints.variantSearch,
          query: {'q': q.trim(), 'page': page, 'limit': limit},
        ),
      ),
    );
    return asMaps(data['items']).map(VariantItem.fromSearchJson).toList();
  }
}
