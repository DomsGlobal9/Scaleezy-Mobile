import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/view_model/view_model.dart';
import 'package:scaleezy/features/purchase_orders/data/purchase_order_models.dart';
import 'package:scaleezy/features/purchase_orders/data/purchase_order_repository.dart';

/// Every purchase order, filtered by where it stands and searched by number or supplier, as the
/// website's purchase orders list.
class PurchaseOrdersViewModel extends ViewModel {
  PurchaseOrdersViewModel([PurchaseOrderRepository? repo])
    : _repo = repo ?? PurchaseOrderRepository();

  final PurchaseOrderRepository _repo;

  /// The website's `?filter=` values and their words; '' is every status.
  static const filters = {
    '': 'All statuses',
    'open': 'Open (waiting for delivery)',
    'draft': 'Draft',
    'sent': 'Sent',
    'partly_received': 'Partly received',
    'received': 'Received',
    'cancelled': 'Cancelled',
  };

  // "Open" is what the dashboard's open purchase orders add up: sent and not fully received.
  static const _statuses = {
    'open': ['SENT', 'PARTIALLY_RECEIVED'],
    'draft': ['DRAFT'],
    'sent': ['SENT'],
    'partly_received': ['PARTIALLY_RECEIVED'],
    'received': ['RECEIVED'],
    'cancelled': ['CANCELLED'],
  };

  List<PurchaseOrderSummary>? _all;
  ApiException? _failure;
  String _filter = '';
  String _query = '';

  /// Null until the first load arrives.
  List<PurchaseOrderSummary>? get all => _all;
  String? get error => _failure?.message;

  /// The last failed load, kept whole so a 403 shows as no access.
  ApiException? get failure => _failure;
  String get filter => _filter;
  String get query => _query;

  Future<void> load() async {
    _failure = null;
    notifyListeners();
    try {
      _all = await _repo.purchaseOrders();
    } on ApiException catch (e) {
      _failure = e;
    }
    notifyListeners();
  }

  /// One of [filters]' keys; anything else (an old link) shows every status.
  void selectFilter(String filter) {
    _filter = filters.containsKey(filter) ? filter : '';
    notifyListeners();
  }

  void search(String text) {
    _query = text;
    notifyListeners();
  }

  static bool _matches(PurchaseOrderSummary po, String f) =>
      f.isEmpty || _statuses[f]!.contains(po.status);

  List<PurchaseOrderSummary> get _loaded =>
      _all ?? const <PurchaseOrderSummary>[];

  /// How many orders a filter would show, before the search.
  int count(String filter) => _loaded.where((p) => _matches(p, filter)).length;

  /// The orders in the chosen filter that match the search.
  List<PurchaseOrderSummary> get visible {
    final q = _query.trim().toLowerCase();
    return _loaded
        .where((po) => _matches(po, _filter))
        .where(
          (po) =>
              po.poNumber.toLowerCase().contains(q) ||
              po.supplierName.toLowerCase().contains(q),
        )
        .toList();
  }
}
