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
  final List<VariantItem> _recent = [];
  String? _lastCode;
  bool _lookingUp = false;
  String? _error;

  VariantItem? get scanned => _scanned;

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

  /// The decoded text goes to /variants/search as `q`; a barcode or SKU matches exactly.
  /// Several matches go to [choose]. Returns the server's message when the search failed.
  Future<String?> lookup(
    String code, {
    required Future<VariantItem?> Function(List<VariantItem> matches) choose,
  }) async {
    final q = code.trim();
    if (q.isEmpty) return null;
    _lookingUp = true;
    _error = null;
    _lastCode = q;
    notifyListeners();
    try {
      final matches = await _products.searchVariants(q, limit: 10);
      if (disposed) return null;
      VariantItem? picked;
      if (matches.length == 1) {
        picked = matches.first;
      } else if (matches.isNotEmpty) {
        picked = await choose(matches);
        if (disposed) return null;
      }
      _lookingUp = false;
      if (picked != null) {
        _scanned = picked;
        _recent
          ..removeWhere((r) => r.id == picked!.id)
          ..insert(0, picked);
        if (_recent.length > 8) _recent.removeLast();
      } else if (matches.isEmpty) {
        _scanned = null;
        _error = 'No product matches "$q".';
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
