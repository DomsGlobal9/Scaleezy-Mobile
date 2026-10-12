import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/view_model/view_model.dart';
import 'package:scaleezy/features/inventory/data/inventory_models.dart';
import 'package:scaleezy/features/inventory/data/inventory_repository.dart';
import 'package:scaleezy/features/products/data/product_models.dart';
import 'package:scaleezy/features/products/data/product_repository.dart';

/// One product: every size and colour with its stock, the colour being looked at, and whether
/// stock moved while the screen was open.
class ProductDetailViewModel extends ViewModel {
  ProductDetailViewModel(
    this.product, {
    ProductRepository? products,
    InventoryRepository? inventory,
  }) : _products = products ?? ProductRepository(),
       _inventory = inventory ?? InventoryRepository();

  final ProductItem product;
  final ProductRepository _products;
  final InventoryRepository _inventory;

  List<VariantItem>? _variants;
  ApiException? _error;
  String? _colour; // null = every colour
  bool _changed = false;

  /// Null until the first load arrives.
  List<VariantItem>? get variants => _variants;
  ApiException? get error => _error;
  String? get colour => _colour;

  /// True once stock was moved, so the list behind can refresh.
  bool get changed => _changed;

  Future<void> load() async {
    _error = null;
    notifyListeners();
    try {
      _variants = await _products.getProductVariants(product.id);
    } on ApiException catch (e) {
      _error = e;
    }
    notifyListeners();
  }

  void selectColour(String? colour) {
    _colour = colour;
    notifyListeners();
  }

  /// After a stock in / out was saved.
  Future<void> stockMoved() {
    _changed = true;
    return load();
  }

  /// inventory:view. The last movements of one size / colour.
  Future<List<TransactionItem>> history(String variantId) =>
      _inventory.getTransactions(variantId: variantId, limit: 15);

  static String _colourKey(VariantItem v) =>
      v.colorName.isEmpty ? '—' : v.colorName;

  /// Distinct colours in the order they appear, with a photo for each when there is one.
  List<(String, String?, int?)> get colours {
    final seen = <String, (String, String?, int?)>{};
    for (final v in _variants ?? product.variants) {
      final key = _colourKey(v);
      final existing = seen[key];
      seen[key] = (key, existing?.$2 ?? v.photoUrl, existing?.$3 ?? v.colorHex);
    }
    return seen.values.toList();
  }

  String? get heroPhoto {
    if (_colour != null) {
      final match = colours.where((c) => c.$1 == _colour).firstOrNull;
      if (match?.$2 != null) return match!.$2;
    }
    return product.coverImageUrl;
  }

  List<VariantItem> get _loaded => _variants ?? const <VariantItem>[];

  /// The loaded variants in the chosen colour.
  List<VariantItem> get visibleVariants => _loaded
      .where((v) => _colour == null || _colourKey(v) == _colour)
      .toList();

  int get _lowLoaded =>
      _loaded.where((v) => v.isLowStock || v.isOutOfStock).length;

  // Until the variants load, the numbers come from the list's summary.
  int get variantCount => _variants?.length ?? product.variantCount;
  int get pieces => _variants == null
      ? product.totalUnits
      : _loaded.fold<int>(0, (a, v) => a + v.quantity);
  int get lowOrOut => _variants == null ? product.lowStockVariants : _lowLoaded;
  bool get warnLow => _lowLoaded > 0;
}
