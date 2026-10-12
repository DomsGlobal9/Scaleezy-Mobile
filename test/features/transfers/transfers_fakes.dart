import 'package:scaleezy/features/transfers/data/transfer_models.dart';
import 'package:scaleezy/features/transfers/data/transfer_repository.dart';

import '../scanner/scanner_fakes.dart';

import '../../support/fixtures.dart';

export '../../support/fixtures.dart' show stockRow;
export '../../support/roles.dart' show store;
export '../scanner/scanner_fakes.dart';

StoreStock stock(
  String variantId, {
  String title = 'Saree',
  int quantity = 5,
}) =>
    StoreStock.fromJson(stockRow(variantId, title: title, quantity: quantity));

/// Answers with the given functions and records every call.
class FakeTransferRepository extends TransferRepository {
  FakeTransferRepository({this.stock, this.send}) : super(offlineClient());

  Future<List<StoreStock>> Function(String locationId, String search)? stock;
  Future<void> Function()? send;
  final searches = <String>[];
  final sent = <Map<String, Object?>>[];

  @override
  Future<List<StoreStock>> stockAt(
    String locationId, {
    required String search,
    int limit = 20,
  }) {
    searches.add('$locationId $search');
    return stock!(locationId, search);
  }

  @override
  Future<void> transfer({
    required String fromId,
    required String toId,
    required Map<String, int> quantities,
    String? notes,
  }) {
    sent.add({
      'from': fromId,
      'to': toId,
      'quantities': Map.of(quantities),
      'notes': notes,
    });
    return send!();
  }
}
