import 'package:dio/dio.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/features/inventory/data/inventory_repository.dart';

/// Records stock in / out calls; [fail] makes them throw.
class FakeInventoryRepository extends InventoryRepository {
  FakeInventoryRepository() : super(ApiClient.withDio(Dio()));

  ApiException? fail;
  final calls = <Map<String, Object?>>[];

  @override
  Future<void> stockIn({
    required String variantId,
    required int quantity,
    required String reason,
    double? unitCost,
    String? notes,
  }) async {
    calls.add({
      'call': 'stockIn',
      'variantId': variantId,
      'quantity': quantity,
      'reason': reason,
      'unitCost': unitCost,
      'notes': notes,
    });
    if (fail != null) throw fail!;
  }

  @override
  Future<void> stockOut({
    required String variantId,
    required int quantity,
    required String reason,
    String? notes,
  }) async {
    calls.add({
      'call': 'stockOut',
      'variantId': variantId,
      'quantity': quantity,
      'reason': reason,
      'notes': notes,
    });
    if (fail != null) throw fail!;
  }
}
