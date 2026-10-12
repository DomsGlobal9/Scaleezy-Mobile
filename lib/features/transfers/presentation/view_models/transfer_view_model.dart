import 'dart:async';

import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/shop/shop_models.dart';
import 'package:scaleezy/core/view_model/view_model.dart';
import 'package:scaleezy/features/products/data/product_repository.dart';
import 'package:scaleezy/features/transfers/data/transfer_models.dart';
import 'package:scaleezy/features/transfers/data/transfer_repository.dart';

/// What a finished move did, for the result card.
typedef MovedStock = ({
  int pieces,
  int items,
  StockLocation from,
  StockLocation to,
});

/// Moving pieces from one store to another: the two stores, the list of items with how many of
/// each, and the move itself. The move is instant -- there is nothing to receive at the other end.
class TransferViewModel extends ViewModel {
  TransferViewModel({TransferRepository? repo, ProductRepository? products})
    : _repo = repo ?? TransferRepository(),
      _products = products ?? ProductRepository();

  final TransferRepository _repo;
  final ProductRepository _products;

  List<StockLocation> _stores = const [];
  StockLocation? _from;
  StockLocation? _to;
  final List<StoreStock> _lines = [];
  final Map<String, int> _qty = {};
  final Map<String, String> _codes = {}; // scanned code -> variantId
  List<StoreStock>? _results;
  bool _searching = false;
  String? _searchError;
  int _searchId = 0;
  Timer? _debounce;
  bool _busy = false;
  String? _error;
  MovedStock? _moved;

  List<StockLocation> get stores => _stores;
  StockLocation? get from => _from;
  StockLocation? get to => _to;

  /// Where the stock can go: any other store.
  List<StockLocation> get destinations =>
      _stores.where((l) => l.id != _from?.id).toList();

  /// The items to move, in the order they were added; each has at least one piece.
  List<StoreStock> get lines => _lines;
  int qty(String variantId) => _qty[variantId] ?? 0;
  int get pieces => _qty.values.fold(0, (a, b) => a + b);

  /// Null while nothing is typed. Only items the source has pieces of.
  List<StoreStock>? get results => _results;
  bool get searching => _searching;
  String? get searchError => _searchError;

  bool get busy => _busy;

  /// Why the last move was refused, shown above the button.
  String? get error => _error;

  /// Set once the stock has moved.
  MovedStock? get moved => _moved;

  /// Starts from the selected store, else the first that is not the online shop. With only one
  /// other store it is the destination; otherwise the person picks.
  void start(StockLocation? selected, List<StockLocation> locations) {
    _stores = locations;
    _from =
        selected ??
        locations.where((l) => l.type != 'ONLINE').firstOrNull ??
        locations.firstOrNull;
    final others = destinations;
    _to = others.length == 1 ? others.first : null;
    notifyListeners();
  }

  /// Empties the list: what can be moved was counted at the old store. Picking the current
  /// destination swaps the two.
  void pickFrom(StockLocation store) {
    if (store.id == _from?.id) return;
    if (store.id == _to?.id) _to = _from;
    _from = store;
    _lines.clear();
    _qty.clear();
    _codes.clear();
    _clearSearch();
    _error = null;
    notifyListeners();
  }

  void pickTo(StockLocation store) {
    _to = store;
    _error = null;
    notifyListeners();
  }

  /// Typing searches once the person pauses.
  void typed(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => search(q));
  }

  /// inventory:view. Items at the source matching [q].
  Future<void> search(String q) async {
    final id = ++_searchId;
    final from = _from;
    if (q.trim().isEmpty || from == null) {
      _clearSearch();
      notifyListeners();
      return;
    }
    _searching = true;
    _searchError = null;
    notifyListeners();
    try {
      final rows = await _repo.stockAt(from.id, search: q);
      // A newer search started meanwhile; this answer is for old text.
      if (disposed || id != _searchId) return;
      _results = rows.where((r) => r.quantity > 0).toList();
    } on ApiException catch (e) {
      if (disposed || id != _searchId) return;
      _searchError = e.message;
    }
    _searching = false;
    notifyListeners();
  }

  void clearSearch() {
    _clearSearch();
    notifyListeners();
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchId++;
    _results = null;
    _searching = false;
    _searchError = null;
  }

  /// One piece of [item], or one more if it is listed already. Returns what to tell the person.
  String add(StoreStock item) {
    final listed = _lines.where((l) => l.variantId == item.variantId);
    final line = listed.firstOrNull ?? item;
    final now = _qty[line.variantId] ?? 0;
    if (now >= line.quantity) {
      return 'All ${line.quantity} of ${line.title} at ${_from?.name} are in the list.';
    }
    if (listed.isEmpty) _lines.add(line);
    _qty[line.variantId] = now + 1;
    _error = null;
    notifyListeners();
    return '+1  ${line.title}  (${now + 1} of ${line.quantity})';
  }

  /// One scan = one piece. The tag is looked up as the scanner does (product:view), then what
  /// the source holds of it (inventory:view). Returns what to flash.
  Future<String> scan(String code) async {
    final from = _from;
    if (from == null) {
      return 'Choose the store the stock leaves and the store it goes to.';
    }
    final known = _lines.where((l) => l.variantId == _codes[code]).firstOrNull;
    if (known != null) return add(known);
    try {
      final matches = await _products.searchVariants(code, limit: 10);
      // A tag reads as one item; several means a loose match, so ask for a search instead.
      final hit = matches.length == 1
          ? matches.first
          : matches
                .where((m) => m.barcode == code || m.sku == code)
                .firstOrNull;
      if (hit == null) {
        return matches.isEmpty
            ? 'No product matches "$code".'
            : 'More than one item matches "$code". Search for it by name.';
      }
      final rows = await _repo.stockAt(from.id, search: hit.sku, limit: 100);
      final row = rows.where((r) => r.variantId == hit.id).firstOrNull;
      if (row == null || row.quantity <= 0) {
        return '${from.name} has none of ${hit.productTitle}.';
      }
      _codes[code] = row.variantId;
      return add(row);
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// Between one and all the pieces the source has.
  void setQty(String variantId, int value) {
    final line = _lines.firstWhere((l) => l.variantId == variantId);
    _qty[variantId] = value.clamp(1, line.quantity);
    notifyListeners();
  }

  void remove(String variantId) {
    _lines.removeWhere((l) => l.variantId == variantId);
    _qty.remove(variantId);
    notifyListeners();
  }

  /// Null when the move can be sent; otherwise the server's own wording, also kept in [error].
  String? validate() {
    _error = _from == null || _to == null
        ? 'Choose the store the stock leaves and the store it goes to.'
        : _from!.id == _to!.id
        ? 'Origin and destination locations must be different'
        : _lines.isEmpty
        ? 'Add at least one item to move.'
        : null;
    notifyListeners();
    return _error;
  }

  /// inventory:transfer. True once the stock has moved; otherwise [error] says why. The server
  /// takes no request key, so a second tap while a move is out is dropped, never sent.
  Future<bool> move(String notes) async {
    if (_busy || validate() != null) return false;
    final from = _from!, to = _to!;
    _busy = true;
    notifyListeners();
    try {
      await _repo.transfer(
        fromId: from.id,
        toId: to.id,
        quantities: Map.of(_qty),
        notes: notes,
      );
      _moved = (pieces: pieces, items: _lines.length, from: from, to: to);
      _lines.clear();
      _qty.clear();
      _codes.clear();
      _clearSearch();
      return true;
    } on ApiException catch (e) {
      // No answer from the app (network, or a proxy's 502/504 -- this route sends neither): it
      // may have gone through, and sending it again would move it twice.
      _error = const {null, 502, 504}.contains(e.statusCode)
          ? 'No answer from the server, so the stock may have moved already. '
                'Check the stock at ${from.name} before trying again.'
          : e.message;
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// After a move: an empty list between the same two stores.
  void startOver() {
    _moved = null;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
