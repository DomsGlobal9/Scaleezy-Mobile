import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/view_model/view_model.dart';
import 'package:scaleezy/features/products/data/product_models.dart';
import 'package:scaleezy/features/products/data/product_repository.dart';

/// The tag scanner: the piece last looked up, what was scanned this session, and the lookup.
class ScannerViewModel extends ViewModel {
  ScannerViewModel([ProductRepository? products])
    : _products = products ?? ProductRepository();

  final ProductRepository _products;

  VariantItem? _scanned;
  bool _exact = false;
  final List<VariantItem> _recent = [];
  String? _lastCode;
  bool _lookingUp = false;
  String? _error;

  VariantItem? get scanned => _scanned;

  /// True when [scanned] matched the code exactly (barcode, SKU or variant code), not a
  /// pick from a name search.
  bool get exactMatch => _exact;

  /// What was scanned this session, newest first -- tap to bring one back.
  List<VariantItem> get recent => _recent;
  bool get lookingUp => _lookingUp;

  /// No match, or the server's message, shown in the result card.
  String? get error => _error;

  /// Whether a code the camera reported should be looked up.
  bool wantsScan(String code) {
    if (code.trim().isEmpty || _lookingUp) return false;
    // Holding a tag in view keeps reporting it; one lookup per tag is enough.
    return !(code == _lastCode && _scanned != null);
  }

  /// As the website's scan search: `/search` first, which matches a barcode, SKU, variant code
  /// or product code exactly (ignoring case). An exact piece is shown; an exact product goes
  /// to [openProduct]. Only [typed] text with no exact hit falls back to `/variants/search`,
  /// whose several matches go to [choose]. Returns the server's message when a call failed.
  Future<String?> lookup(
    String code, {
    required Future<VariantItem?> Function(List<VariantItem> matches) choose,
    Future<void> Function(ProductItem product)? openProduct,
    bool typed = false,
  }) async {
    final q = code.trim();
    if (q.isEmpty) return null;
    _lookingUp = true;
    _error = null;
    _lastCode = q;
    notifyListeners();
    try {
      final found = await _products.search(q);
      if (disposed) return null;

      VariantItem? picked;
      var exact = false;
      var offered = false; // several name matches were offered and none taken
      final hit = found.variants
          .where((h) => h.exactCode(q) != null)
          .firstOrNull;
      if (hit != null) {
        // /search names the piece; its stock and prices come from the variant search.
        final rows = await _products.searchVariants(
          hit.exactCode(q)!,
          limit: 10,
        );
        if (disposed) return null;
        picked = rows.where((v) => v.id == hit.id).firstOrNull;
        exact = picked != null;
      }

      final product = found.products
          .where((h) => h.exactCode(q) != null)
          .firstOrNull;
      if (picked == null && product != null && openProduct != null) {
        final item = await _products.getProduct(product.id);
        if (disposed) return null;
        _lookingUp = false;
        notifyListeners();
        await openProduct(item);
        return null;
      }

      if (picked == null && typed) {
        final matches = await _products.searchVariants(q, limit: 10);
        if (disposed) return null;
        if (matches.length == 1) {
          picked = matches.first;
        } else if (matches.isNotEmpty) {
          picked = await choose(matches);
          if (disposed) return null;
          offered = picked == null;
        }
      }

      _lookingUp = false;
      if (picked != null) {
        _scanned = picked;
        _exact = exact;
        _recent
          ..removeWhere((r) => r.id == picked!.id)
          ..insert(0, picked);
        if (_recent.length > 8) _recent.removeLast();
      } else if (!offered) {
        _scanned = null;
        _error = 'Nothing found for "$q". Check the barcode or SKU.';
      }
    } on ApiException catch (e) {
      if (disposed) return null;
      _lookingUp = false;
      _error = e.message;
      notifyListeners();
      return e.message;
    }
    notifyListeners();
    return null;
  }
}
