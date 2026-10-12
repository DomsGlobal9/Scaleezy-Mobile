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
       _reason = (isStockIn ? stockInReasons : stockOutReasons).first;

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

  /// The typed text, as the fields hold it.
  String quantity = '1';
  String cost = '';

  String _reason;
  bool _busy = false;
  String? _error;

  List<String> get reasons => isStockIn ? stockInReasons : stockOutReasons;
  String get reason => _reason;
  bool get busy => _busy;
  String? get error => _error;

  set reason(String value) {
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
      return _fail('That purchase cost is not a number.');
    }

    _busy = true;
    _error = null;
    notifyListeners();
    try {
      if (isStockIn) {
        await _inventory.stockIn(
          variantId: variantId,
          quantity: qty,
          reason: _reason,
          unitCost: unitCost,
        );
      } else {
        await _inventory.stockOut(
          variantId: variantId,
          quantity: qty,
          reason: _reason,
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
