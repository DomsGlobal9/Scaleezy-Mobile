import 'package:scaleezy/features/stock_counts/data/stock_count_models.dart';
import 'package:scaleezy/features/stock_counts/data/stock_count_repository.dart';

import '../../support/fake_api.dart';
import '../../support/fixtures.dart';

export '../../support/fixtures.dart' show countJson, lineJson;
export '../../support/roles.dart' show store;

StockCount count(
  String id, {
  String name = 'October 2026 Full Count',
  String status = 'IN_PROGRESS',
  int items = 3,
  int? matched,
  int? adjusted,
  String? accuracy,
}) => StockCount.fromJson(
  countJson(
    id,
    name: name,
    status: status,
    items: items,
    matched: matched,
    adjusted: adjusted,
    accuracy: accuracy,
  ),
);

StockCountDetail detail({
  String status = 'IN_PROGRESS',
  List<Map<String, Object?>>? items,
}) => StockCountDetail.fromJson({
  ...countJson('c1', status: status),
  'items':
      items ??
      [
        lineJson('a', title: 'Cotton Kurta', expected: 4),
        lineJson('b', title: 'Silk Saree', expected: 10, counted: 10),
        lineJson('c', title: 'Linen Shirt', expected: 2, counted: 3),
      ],
});

/// The bare line `PUT /stock-counts/:id/items/:itemId` answers (no variant).
StockCountItem savedLine(String id, {required int expected, int? counted}) =>
    StockCountItem.fromJson({
      'id': id,
      'stockCountId': 'c1',
      'variantId': 'v-$id',
      'sku': 'SKU-$id',
      'variantCode': 'VC-$id',
      'expectedQty': expected,
      'countedQty': counted,
    });

/// Answers with the given functions and records each call, in order.
class FakeStockCountRepository extends StockCountRepository {
  FakeStockCountRepository({
    this.list,
    this.one,
    this.create,
    this.save,
    this.action,
  }) : super(offlineClient());

  Future<List<StockCount>> Function()? list;
  Future<StockCountDetail> Function()? one;
  Future<StockCount> Function()? create;
  Future<StockCountItem> Function(String itemId, int? counted)? save;

  /// start, complete or cancel.
  Future<StockCount> Function(String what)? action;
  final calls = <String>[];

  @override
  Future<List<StockCount>> stockCounts() {
    calls.add('list');
    return list!();
  }

  @override
  Future<StockCountDetail> stockCount(String id) {
    calls.add('get $id');
    return one!();
  }

  @override
  Future<StockCount> createStockCount({
    required String name,
    required String locationId,
    String? category,
  }) {
    calls.add('create $name $locationId $category');
    return create!();
  }

  @override
  Future<StockCountItem> setCounted(
    String countId,
    String itemId,
    int? counted,
  ) {
    calls.add('set $countId $itemId $counted');
    return save!(itemId, counted);
  }

  @override
  Future<StockCount> startStockCount(String id) {
    calls.add('start $id');
    return action!('start');
  }

  @override
  Future<StockCount> completeStockCount(String id) {
    calls.add('complete $id');
    return action!('complete');
  }

  @override
  Future<StockCount> cancelStockCount(String id) {
    calls.add('cancel $id');
    return action!('cancel');
  }
}
