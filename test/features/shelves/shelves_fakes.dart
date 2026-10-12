import 'package:scaleezy/features/shelves/data/shelf_models.dart';
import 'package:scaleezy/features/shelves/data/shelf_repository.dart';

import '../../support/fake_api.dart';

export '../../support/fake_api.dart' show offlineClient;
export '../../support/roles.dart' show store;

ShelfItem item(String variantId, {String title = 'Saree', int quantity = 0}) =>
    ShelfItem(
      variantId: variantId,
      productId: 'p-$variantId',
      title: title,
      sku: 'SKU-$variantId',
      colorName: 'Red',
      quantity: quantity,
    );

ShelfSpot shelf(
  String id, {
  String? name,
  int pieces = 0,
  bool active = true,
  List<ShelfSpot> children = const [],
}) => ShelfSpot(
  id: id,
  kind: children.isEmpty ? 'SHELF' : 'RACK',
  code: id,
  address: id.toUpperCase(),
  name: name,
  active: active,
  pieces: pieces,
  branchPieces: pieces,
  children: children,
);

ShelfTree treeOf(
  String locationId,
  List<ShelfSpot> spots, {
  int total = 10,
  int onShelves = 7,
}) => ShelfTree(
  locationId: locationId,
  locationName: 'Store $locationId',
  spots: spots,
  count: spots.expand((s) => s.flatten).length,
  totalPieces: total,
  onShelves: onShelves,
  notShelved: total - onShelves,
);

SpotContents spotContents(
  String id, {
  String locationId = 'L1',
  bool holdsStock = true,
  List<ShelfItem> items = const [],
}) => SpotContents(
  spotId: id,
  address: id.toUpperCase(),
  kind: 'SHELF',
  locationId: locationId,
  locationName: 'Store $locationId',
  holdsStock: holdsStock,
  total: items.fold(0, (a, i) => a + i.quantity),
  overCapacity: false,
  items: items,
);

/// Answers each call with the matching function and records what was asked, in order.
class FakeShelfRepository extends ShelfRepository {
  FakeShelfRepository({
    this.tree,
    this.scan,
    this.spotAnswer,
    this.find,
    this.waiting,
    this.write,
  }) : super(offlineClient());

  Future<ShelfTree> Function(String locationId)? tree;
  Future<SpotContents> Function(String code)? scan;
  Future<SpotContents> Function(String spotId)? spotAnswer;
  Future<List<WhereItem>> Function(String q)? find;
  Future<List<NotShelvedItem>> Function()? waiting;

  /// Answers putAway and moveOnShelves: the server's warning, if any.
  Future<String?> Function()? write;

  final calls = <String>[];
  final writes = <Map<String, Object?>>[];

  @override
  Future<ShelfTree> shelfTree(String locationId) {
    calls.add('tree $locationId');
    return tree!(locationId);
  }

  @override
  Future<SpotContents> scanSpot(String code, {String? locationId}) {
    calls.add('scan $code @$locationId');
    return scan!(code);
  }

  @override
  Future<SpotContents> spot(String spotId) {
    calls.add('spot $spotId');
    return spotAnswer!(spotId);
  }

  @override
  Future<List<WhereItem>> findOnShelves(String q, {String? locationId}) {
    calls.add('find $q @$locationId');
    return find!(q);
  }

  @override
  Future<List<NotShelvedItem>> notShelved(String locationId) {
    calls.add('waiting $locationId');
    return waiting!();
  }

  @override
  Future<String?> putAway({
    required String locationId,
    required String variantId,
    required String spotId,
    required int quantity,
  }) {
    calls.add('putAway');
    writes.add({
      'locationId': locationId,
      'variantId': variantId,
      'spotId': spotId,
      'quantity': quantity,
    });
    return write!();
  }

  @override
  Future<String?> moveOnShelves({
    required String locationId,
    required String variantId,
    String? fromSpotId,
    String? toSpotId,
    required int quantity,
  }) {
    calls.add('move');
    writes.add({
      'locationId': locationId,
      'variantId': variantId,
      'fromSpotId': fromSpotId,
      'toSpotId': toSpotId,
      'quantity': quantity,
    });
    return write!();
  }
}
