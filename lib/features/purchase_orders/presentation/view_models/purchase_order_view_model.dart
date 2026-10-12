import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/view_model/view_model.dart';
import 'package:scaleezy/features/purchase_orders/data/purchase_order_models.dart';
import 'package:scaleezy/features/purchase_orders/data/purchase_order_repository.dart';

/// One purchase order with its lines, and whether a delivery was received while it was open.
class PurchaseOrderViewModel extends ViewModel {
  PurchaseOrderViewModel(this.poId, [PurchaseOrderRepository? repo])
    : _repo = repo ?? PurchaseOrderRepository();

  final String poId;
  final PurchaseOrderRepository _repo;

  PurchaseOrderDetail? _po;
  String? _error;
  bool _changed = false;

  /// Null until the first load arrives.
  PurchaseOrderDetail? get po => _po;
  String? get error => _error;

  /// True once a delivery was received, so the list behind can refresh.
  bool get changed => _changed;

  int get ordered => _po?.lines.fold<int>(0, (a, l) => a + l.ordered) ?? 0;
  int get received => _po?.lines.fold<int>(0, (a, l) => a + l.received) ?? 0;

  Future<void> load() async {
    _error = null;
    notifyListeners();
    try {
      _po = await _repo.purchaseOrder(poId);
    } on ApiException catch (e) {
      _error = e.message;
    }
    notifyListeners();
  }

  /// After a delivery was received.
  Future<void> deliveryReceived() {
    _changed = true;
    return load();
  }
}
