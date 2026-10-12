import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/view_model/view_model.dart';
import 'package:scaleezy/features/inventory/data/inventory_repository.dart';

/// One stock in / out for a variant: what was typed, the reason, and sending it.
class StockMovementViewModel extends ViewModel {
  StockMovementViewModel({
    required this.variantId,
    required this.isStockIn,
    InventoryRepository? inventory,
  }) : _inventory = inventory ?? InventoryRepository(),
       // Stock out starts with no reason, as the web: a default wrote damage off as a sample.
       _reason = isStockIn ? stockInReasons.first : null;

  final String variantId;
  final bool isStockIn;
  final InventoryRepository _inventory;

  // The same five the web app's Receive Stock offers, in its order.
  static const stockInReasons = [
    'PURCHASE',
    'RETURN',
    'INITIAL_STOCK',
    'SUPPLIER_DELIVERY',
    'PURCHASE_RECEIPT',
  ];

  // The only reasons the server takes for stock off by hand; sales remove stock themselves.
  static const stockOutReasons = ['DAMAGE', 'SAMPLE', 'RETURN_TO_VENDOR'];

  /// What each reason reads as on screen.
  static const reasonLabels = {
    'PURCHASE': 'Purchase',
    'RETURN': 'Return',
    'INITIAL_STOCK': 'Initial stock',
    'SUPPLIER_DELIVERY': 'Supplier delivery',
    'PURCHASE_RECEIPT': 'Purchase receipt',
    'DAMAGE': 'Damaged',
    'SAMPLE': 'Sample',
    'RETURN_TO_VENDOR': 'Returned to the supplier',
  };

  static const noReasonMessage =
      'Choose why these pieces are going out: damaged, a sample, or returned to the supplier.';
  static const paisaMessage =
      'Prices go to the paisa: use at most 2 digits after the point, for example 1499.50.';

  /// The typed text, as the fields hold it.
  String quantity = '1';
  String cost = '';

  String? _reason;
  bool _busy = false;
  String? _error;

  List<String> get reasons => isStockIn ? stockInReasons : stockOutReasons;

  /// Null until the person picks one (stock out only).
  String? get reason => _reason;
  bool get busy => _busy;
  String? get error => _error;

  set reason(String? value) {
    _reason = value;
    notifyListeners();
  }

  /// A quick-add pill. Returns the new quantity for the field.
  String addQuantity(int amount) {
    final current = int.tryParse(quantity) ?? 0;
    quantity = (current + amount).clamp(1, 9999).toString();
    return quantity;
  }

  /// Sends it to /inventory/stock-in or stock-out. Returns null once the server accepted it,
  /// otherwise what is wrong (also kept in [error]).
  Future<String?> save() async {
    final qty = int.tryParse(quantity.trim());
    if (qty == null || qty <= 0) {
      return _fail('Enter how many pieces, as a whole number above zero.');
    }
    final costText = cost.trim();
    final unitCost = costText.isEmpty ? null : double.tryParse(costText);
    if (costText.isNotEmpty && unitCost == null) {
      return _fail('What you paid is not a number.');
    }
    // The server's rule (web utils/money.js hasPartPaise): 1499.999 would be rounded away.
    if (unitCost != null &&
        ((unitCost * 100) - (unitCost * 100).round()).abs() >= 1e-6) {
      return _fail(paisaMessage);
    }
    final reason = _reason;
    if (reason == null) return _fail(noReasonMessage);

    _busy = true;
    _error = null;
    notifyListeners();
    try {
      if (isStockIn) {
        await _inventory.stockIn(
          variantId: variantId,
          quantity: qty,
          reason: reason,
          unitCost: unitCost,
        );
      } else {
        await _inventory.stockOut(
          variantId: variantId,
          quantity: qty,
          reason: reason,
        );
      }
      // Stays busy: the dialog closes now.
      return null;
    } on ApiException catch (e) {
      _busy = false;
      return _fail(e.message);
    }
  }

  String _fail(String message) {
    _error = message;
    notifyListeners();
    return message;
  }
}
