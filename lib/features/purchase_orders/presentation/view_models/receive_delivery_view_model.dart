import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/view_model/view_model.dart';
import 'package:scaleezy/features/purchase_orders/data/purchase_order_models.dart';
import 'package:scaleezy/features/purchase_orders/data/purchase_order_repository.dart';

/// Counting a delivery against the lines still to come, then adding it to stock.
class ReceiveDeliveryViewModel extends ViewModel {
  ReceiveDeliveryViewModel(this.po, [PurchaseOrderRepository? repo])
    : _repo = repo ?? PurchaseOrderRepository(),
      lines = po.lines.where((l) => l.outstanding > 0).toList();

  final PurchaseOrderDetail po;
  final PurchaseOrderRepository _repo;

  /// The lines with pieces still to come.
  final List<PurchaseOrderLine> lines;
  late final Map<String, int> _qty = {for (final l in lines) l.id: 0};
  // One key for this delivery: if a slow submit is retried, the server counts it once.
  final requestKey = PurchaseOrderRepository.newRequestKey();
  bool _busy = false;
  String? _error;

  bool get busy => _busy;

  /// Why the last submit was refused, shown under the button.
  String? get error => _error;

  int qty(String lineId) => _qty[lineId]!;
  int get total => _qty.values.fold(0, (a, b) => a + b);
  int get outstanding => lines.fold<int>(0, (a, l) => a + l.outstanding);

  /// Lines with at least one piece counted.
  int get countedLines => lines.where((l) => _qty[l.id]! > 0).length;

  void setQty(String lineId, int value) {
    _qty[lineId] = value;
    notifyListeners();
  }

  void allArrived() {
    for (final l in lines) {
      _qty[l.id] = l.outstanding;
    }
    notifyListeners();
  }

  /// Each scan of a piece's tag counts one against its line. Returns what to tell the person.
  String scan(String code) {
    final line = lines
        .where((l) => l.barcode == code || l.sku == code)
        .firstOrNull;
    if (line == null) return 'Not on this order: $code';
    final now = _qty[line.id]!;
    if (now >= line.outstanding) {
      return 'All ${line.outstanding} of ${line.title} already counted';
    }
    setQty(line.id, now + 1);
    return '+1  ${line.title}  (${now + 1}/${line.outstanding})';
  }

  /// Null when the delivery can be sent; otherwise the reason, also kept in [error].
  String? validate(String receivedBy) {
    final problem = total == 0
        ? 'Count at least one piece first.'
        : receivedBy.trim().length < 2
        ? 'Enter the name of the person who received the goods.'
        : null;
    if (problem != null) {
      _error = problem;
      notifyListeners();
    }
    return problem;
  }

  /// Whether the goods would go into [storeId] (the app's store) rather than the active store
  /// the order is for: worth asking first, as the website does, since nothing downstream notices.
  bool intoOtherStore(String? storeId) =>
      storeId != null &&
      po.summary.deliverToActive &&
      po.summary.deliverToId != null &&
      po.summary.deliverToId != storeId;

  String? _done;

  /// What to say once received: "Received — GRN-0001", as the website.
  String? get done => _done;

  /// purchase_order:receive, into [locationId] (the order's own store when null). Null on
  /// success, otherwise the server's message. Stays busy after success because the screen
  /// closes.
  Future<String?> receive({
    required String receivedBy,
    required String reference,
    String? locationId,
  }) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final r = await _repo.receivePurchaseOrder(
        po.summary.id,
        quantities: _qty,
        receivedByName: receivedBy,
        locationId: locationId,
        supplierReference: reference,
        requestKey: requestKey,
      );
      _done = r.receiptNumber == null
          ? 'Goods received successfully'
          : '${r.duplicate ? 'Already received' : 'Received'} — ${r.receiptNumber}';
      return null;
    } on ApiException catch (e) {
      _busy = false;
      notifyListeners();
      return e.message;
    }
  }
}
