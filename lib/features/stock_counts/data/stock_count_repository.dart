import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/network/api_endpoints.dart';
import 'package:scaleezy/core/utils/json_parse.dart';
import 'package:scaleezy/features/stock_counts/data/stock_count_models.dart';

/// Stock counts (audits). Every answer is `{success, data}`. Permissions noted per call.
class StockCountRepository {
  StockCountRepository([ApiClient? client])
    : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  /// stock_count:view. Every count of the shop, newest first.
  Future<List<StockCount>> stockCounts() async => asMaps(
    dataOf(await _api.get(ApiEndpoints.stockCounts)),
  ).map(StockCount.fromJson).toList();

  /// stock_count:create. A DRAFT holding every variant on sale (of [category], if given),
  /// with the store's stock as the expected figure.
  Future<StockCount> createStockCount({
    required String name,
    required String locationId,
    String? category, // WOMEN, MEN, KIDS, UNISEX
  }) async => StockCount.fromJson(
    asMap(
      dataOf(
        await _api.post(
          ApiEndpoints.stockCounts,
          body: {
            'name': name.trim(),
            'locationId': locationId,
            'categoryId': ?category,
          },
        ),
      ),
    ),
  );

  /// stock_count:view
  Future<StockCountDetail> stockCount(String id) async =>
      StockCountDetail.fromJson(
        asMap(dataOf(await _api.get(ApiEndpoints.stockCount(id)))),
      );

  /// stock_count:create. DRAFT -> IN_PROGRESS.
  Future<StockCount> startStockCount(String id) async => StockCount.fromJson(
    asMap(dataOf(await _api.post(ApiEndpoints.startStockCount(id)))),
  );

  /// stock_count:update. [counted] null puts the line back to "not counted". The answer is the
  /// bare line (no product), with expectedQty reset to the stock at this moment.
  Future<StockCountItem> setCounted(
    String countId,
    String itemId,
    int? counted,
  ) async => StockCountItem.fromJson(
    asMap(
      dataOf(
        await _api.put(
          ApiEndpoints.stockCountItem(countId, itemId),
          body: {'countedQty': counted},
        ),
      ),
    ),
  );

  /// stock_count:complete. Corrects stock for counted lines that differ; uncounted lines are
  /// left alone. Answers the count with accuracy, matchedItems and adjustedItems.
  Future<StockCount> completeStockCount(String id) async => StockCount.fromJson(
    asMap(dataOf(await _api.post(ApiEndpoints.completeStockCount(id)))),
  );

  /// The shop owner only (checked by the server, not a permission). No stock changes.
  Future<StockCount> cancelStockCount(String id) async => StockCount.fromJson(
    asMap(dataOf(await _api.post(ApiEndpoints.cancelStockCount(id)))),
  );
}
