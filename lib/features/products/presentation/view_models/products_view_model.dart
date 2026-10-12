import 'dart:async';

import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/view_model/view_model.dart';
import 'package:scaleezy/features/products/data/product_models.dart';
import 'package:scaleezy/features/products/data/product_repository.dart';

/// The server's product sorts, as a shopkeeper would say them.
enum ProductSort {
  newest('Newest first', 'createdAt', 'desc'),
  updated('Recently changed', 'updatedAt', 'desc'),
  nameAz('Name A–Z', 'title', 'asc'),
  priceLow('Price: low to high', 'basePrice', 'asc'),
  priceHigh('Price: high to low', 'basePrice', 'desc');

  final String label;
  final String field;
  final String order;
  const ProductSort(this.label, this.field, this.order);
}

/// The catalogue: a paged list with search, category, sort and status filters.
class ProductsViewModel extends ViewModel {
  ProductsViewModel([ProductRepository? repo])
    : _repo = repo ?? ProductRepository();

  final ProductRepository _repo;

  /// Every category; the filter sends none.
  static const all = 'ALL';

  /// Used until (or if never) the shop's own list arrives from the catalogue.
  static const fallbackCategories = <CatalogOption>[
    (value: 'WOMEN', label: 'Women'),
    (value: 'MEN', label: 'Men'),
    (value: 'KIDS', label: 'Kids'),
    (value: 'UNISEX', label: 'Unisex'),
  ];
  // null = the server's default of active + draft.
  static const statuses = <String?, String>{
    null: 'Active & Drafts',
    'ACTIVE': 'Published only',
    'DRAFT': 'Drafts only',
    'OUT_OF_STOCK': 'Out of stock',
    'ARCHIVED': 'Archived',
  };

  String _query = '';
  String _category = all;
  List<CatalogOption> _categories = fallbackCategories;
  String? _status;
  ProductSort _sort = ProductSort.newest;
  bool _grid = true;

  final List<ProductItem> _products = [];
  int _page = 0;
  int _total = 0;
  bool _hasMore = true;
  bool _loading = false;
  ApiException? _error;
  int _requestId = 0;
  Timer? _debounce;

  String get query => _query;
  String get category => _category;

  /// [value]'s name in the shop's catalogue, else "WOMEN" reads "Women".
  String categoryLabel(String value) =>
      _categories.where((c) => c.value == value).firstOrNull?.label ??
      (value.isEmpty
          ? ''
          : value[0].toUpperCase() +
                value.substring(1).toLowerCase().replaceAll('_', ' '));

  /// "All" first, then the shop's categories.
  List<CatalogOption> get categories => [
    (value: all, label: 'All'),
    ..._categories,
  ];
  String? get status => _status;
  ProductSort get sort => _sort;
  bool get grid => _grid;
  List<ProductItem> get products => _products;

  /// 0 until the first page arrives.
  int get page => _page;
  int get total => _total;
  bool get hasMore => _hasMore;
  bool get loading => _loading;

  /// Kept whole so a 403 can show "no access" rather than a retry.
  ApiException? get error => _error;
  bool get isFiltered => _status != null || _sort != ProductSort.newest;

  /// Starts again from page one with the current search and filters.
  Future<void> reload() async {
    _requestId++;
    _products.clear();
    _page = 0;
    _hasMore = true;
    _loading = false;
    _error = null;
    notifyListeners();
    await loadMore();
  }

  Future<void> loadMore() async {
    if (_loading || !_hasMore) return;
    final id = _requestId;
    _loading = true;
    notifyListeners();
    try {
      final result = await _repo.getProducts(
        page: _page + 1,
        search: _query,
        category: _category == all ? null : _category,
        status: _status,
        sortBy: _sort.field,
        order: _sort.order,
      );
      // A reload started meanwhile; this page belongs to the old list.
      if (disposed || id != _requestId) return;
      _products.addAll(result.items);
      _page = result.page;
      _total = result.total;
      _hasMore = result.hasMore;
      _error = null;
    } on ApiException catch (e) {
      if (disposed || id != _requestId) return;
      _error = e;
    }
    _loading = false;
    notifyListeners();
  }

  /// The shop's categories from the catalogue; the built-in list stays if that fails.
  Future<void> loadCategories() async {
    try {
      final loaded = await _repo.getCategories();
      if (disposed || loaded.isEmpty) return;
      _categories = loaded;
      notifyListeners();
    } on ApiException {
      // The fallback list is still on screen.
    }
  }

  /// Typing searches once the person pauses.
  void search(String text) {
    _query = text;
    notifyListeners();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), reload);
  }

  void clearSearch() {
    _debounce?.cancel();
    _query = '';
    reload();
  }

  void selectCategory(String category) {
    if (category == _category) return;
    _category = category;
    reload();
  }

  void applyFilters(ProductSort sort, String? status) {
    _sort = sort;
    _status = status;
    reload();
  }

  void toggleView() {
    _grid = !_grid;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
