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

  static const categories = ['ALL', 'WOMEN', 'MEN', 'KIDS', 'UNISEX'];
  // null = the server's default of active + draft.
  static const statuses = <String?, String>{
    null: 'Active & Drafts',
    'ACTIVE': 'Published only',
    'DRAFT': 'Drafts only',
    'OUT_OF_STOCK': 'Out of stock',
    'ARCHIVED': 'Archived',
  };

  String _query = '';
  String _category = 'ALL';
  String? _status;
  ProductSort _sort = ProductSort.newest;
  bool _grid = true;

  final List<ProductItem> _products = [];
  int _page = 0;
  int _total = 0;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;
  int _requestId = 0;
  Timer? _debounce;

  String get query => _query;
  String get category => _category;
  String? get status => _status;
  ProductSort get sort => _sort;
  bool get grid => _grid;
  List<ProductItem> get products => _products;

  /// 0 until the first page arrives.
  int get page => _page;
  int get total => _total;
  bool get hasMore => _hasMore;
  bool get loading => _loading;
  String? get error => _error;
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
        category: _category == 'ALL' ? null : _category,
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
      _error = e.message;
    }
    _loading = false;
    notifyListeners();
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
