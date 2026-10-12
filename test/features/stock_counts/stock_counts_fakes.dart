import 'package:dio/dio.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/session/auth_user.dart';
import 'package:scaleezy/core/shop/shop_context.dart';
import 'package:scaleezy/core/shop/shop_models.dart';
import 'package:scaleezy/features/stock_counts/data/stock_count_models.dart';
import 'package:scaleezy/features/stock_counts/data/stock_count_repository.dart';

import '../auth/auth_fakes.dart';

/// A client that is never called: the fakes below answer instead.
ApiClient offlineClient() => ApiClient.withDio(Dio());

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

StockLocation store(String id, {String type = 'STORE'}) => StockLocation(
  id: id,
  code: id,
  name: 'Store $id',
  type: type,
  active: true,
);

/// FakeAuthSession answers [user] only; screens here also ask [can].
class FakeSession extends FakeAuthSession {
  FakeSession(AuthUser user) : super(signedIn: user);

  @override
  bool can(String permission) => signedIn?.can(permission) ?? false;
}

/// The shop's stores, without loading anything.
class FakeShopContext extends ShopContext {
  FakeShopContext(this._locations) : super(offlineClient());

  final List<StockLocation> _locations;

  @override
  List<StockLocation> get locations => _locations;
}

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
