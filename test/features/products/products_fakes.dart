import 'package:dio/dio.dart';
import 'package:scaleezy/core/models/paged.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/features/inventory/data/inventory_models.dart';
import 'package:scaleezy/features/inventory/data/inventory_repository.dart';
import 'package:scaleezy/features/products/data/product_models.dart';
import 'package:scaleezy/features/products/data/product_repository.dart';

/// A client that is never called: the fakes below answer instead.
ApiClient offlineClient() => ApiClient.withDio(Dio());

ProductItem product(
  String id, {
  String title = 'Saree',
  int totalUnits = 0,
  int variantCount = 0,
  int lowStockVariants = 0,
}) => ProductItem.fromJson({
  'id': id,
  'title': title,
  'productCode': 'SE-$id',
  'category': 'WOMEN',
  'productType': 'UNSTITCHED',
  'basePrice': '1499.00',
  'status': 'ACTIVE',
  'variantSummary': {
    'variantCount': variantCount,
    'totalUnits': totalUnits,
    'lowStockVariants': lowStockVariants,
  },
});

VariantItem variant(
  String id, {
  required String colour,
  String size = 'M',
  int quantity = 5,
  int reorderLevel = 0,
  Object? costPrice,
  Object? averageCost,
}) => VariantItem.fromJson({
  'id': id,
  'sku': 'SKU-$id',
  'barcode': '',
  'size': size,
  'colorName': colour,
  'reorderLevel': reorderLevel,
  'totalQuantity': quantity,
  'costPrice': ?costPrice,
  'averageCost': ?averageCost,
});

/// Records each getProducts call and answers with [answer].
class FakeProductRepository extends ProductRepository {
  FakeProductRepository({this.answer, this.variants, this.categories})
    : super(offlineClient());

  Future<Paged<ProductItem>> Function(int page)? answer;
  Future<List<VariantItem>> Function()? variants;

  /// Unset: the catalogue call fails, as when offline.
  Future<List<CatalogOption>> Function()? categories;
  final calls = <Map<String, Object?>>[];

  @override
  Future<Paged<ProductItem>> getProducts({
    int page = 1,
    int limit = 20,
    String? search,
    String? category,
    String? status,
    String sortBy = 'createdAt',
    String order = 'desc',
  }) {
    calls.add({
      'page': page,
      'search': search,
      'category': category,
      'status': status,
      'sortBy': sortBy,
      'order': order,
    });
    return answer!(page);
  }

  @override
  Future<List<VariantItem>> getProductVariants(String productId) => variants!();

  @override
  Future<List<CatalogOption>> getCategories() =>
      categories?.call() ??
      Future.error(const ApiException('Could not reach the server.'));
}

class FakeInventoryRepository extends InventoryRepository {
  FakeInventoryRepository() : super(offlineClient());

  final historyFor = <String>[];

  @override
  Future<List<TransactionItem>> getTransactions({
    String? variantId,
    int limit = 50,
  }) async {
    historyFor.add(variantId!);
    return const [];
  }
}
