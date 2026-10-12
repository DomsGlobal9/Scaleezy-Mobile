import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/view_model/view_model.dart';
import 'package:scaleezy/features/purchase_orders/data/purchase_order_models.dart';
import 'package:scaleezy/features/purchase_orders/data/purchase_order_repository.dart';

/// Every purchase order, filtered by where it stands.
class PurchaseOrdersViewModel extends ViewModel {
  PurchaseOrdersViewModel([PurchaseOrderRepository? repo])
    : _repo = repo ?? PurchaseOrderRepository();

  final PurchaseOrderRepository _repo;

  static const filters = {
    'OPEN': 'To receive',
    'DRAFT': 'Draft',
    'RECEIVED': 'Received',
    'CANCELLED': 'Cancelled',
    'ALL': 'All',
  };

  List<PurchaseOrderSummary>? _all;
  String? _error;
  String _filter = 'OPEN';

  /// Null until the first load arrives.
  List<PurchaseOrderSummary>? get all => _all;
  String? get error => _error;
  String get filter => _filter;

  Future<void> load() async {
    _error = null;
    notifyListeners();
    try {
      _all = await _repo.purchaseOrders();
    } on ApiException catch (e) {
      _error = e.message;
    }
    notifyListeners();
  }

  void selectFilter(String filter) {
    _filter = filter;
    notifyListeners();
  }

  static bool _matches(PurchaseOrderSummary po, String f) => switch (f) {
    'OPEN' => po.canReceive,
    'ALL' => true,
    _ => po.status == f,
  };

  List<PurchaseOrderSummary> get _loaded =>
      _all ?? const <PurchaseOrderSummary>[];

  /// How many orders a filter would show.
  int count(String filter) => _loaded.where((p) => _matches(p, filter)).length;

  /// The orders in the chosen filter.
  List<PurchaseOrderSummary> get visible =>
      _loaded.where((po) => _matches(po, _filter)).toList();
}
