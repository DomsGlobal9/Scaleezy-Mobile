import 'package:dio/dio.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/features/products/data/product_models.dart';
import 'package:scaleezy/features/products/data/product_repository.dart';

/// A client that is never called: the fake below answers instead.
ApiClient offlineClient() => ApiClient.withDio(Dio());

VariantItem piece(String id, {String title = 'Saree', int quantity = 5}) =>
    VariantItem.fromJson({
      'id': id,
      'sku': 'SKU-$id',
      'barcode': '890$id',
      'size': 'M',
      'colorName': 'Red',
      'totalQuantity': quantity,
      'product': {'title': title},
    });

/// A /search answer naming [variants] as exact hits on their barcode.
SearchResults exactHits(List<VariantItem> variants) => SearchResults(
  variants: [
    for (final v in variants)
      SearchHit(
        id: v.id,
        label: v.productTitle,
        code: 'V-${v.id}',
        sku: v.sku,
        barcode: v.barcode,
      ),
  ],
);

/// Records each searchVariants call and answers with [answer]; /search answers with [found]
/// (nothing exact unless set).
class FakeProductRepository extends ProductRepository {
  FakeProductRepository(this.answer, {this.found}) : super(offlineClient());

  Future<List<VariantItem>> Function(String q) answer;
  Future<SearchResults> Function(String q)? found;
  final calls = <Map<String, Object?>>[];
  final searched = <String>[];
  final opened = <String>[];

  @override
  Future<SearchResults> search(String q) {
    searched.add(q);
    return found?.call(q) ?? Future.value(const SearchResults());
  }

  @override
  Future<ProductItem> getProduct(String id) async {
    opened.add(id);
    return ProductItem.fromJson({'id': id, 'title': 'Product $id'});
  }

  @override
  Future<List<VariantItem>> searchVariants(
    String q, {
    int page = 1,
    int limit = 20,
  }) {
    calls.add({'q': q, 'page': page, 'limit': limit});
    return answer(q);
  }
}
