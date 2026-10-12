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

/// Records each searchVariants call and answers with [answer].
class FakeProductRepository extends ProductRepository {
  FakeProductRepository(this.answer) : super(offlineClient());

  Future<List<VariantItem>> Function(String q) answer;
  final calls = <Map<String, Object?>>[];

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
