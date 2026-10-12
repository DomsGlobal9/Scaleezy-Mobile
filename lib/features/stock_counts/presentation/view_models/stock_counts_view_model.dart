import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/view_model/view_model.dart';
import 'package:scaleezy/features/stock_counts/data/stock_count_models.dart';
import 'package:scaleezy/features/stock_counts/data/stock_count_repository.dart';

/// Every stock count of the shop, and starting a new one.
class StockCountsViewModel extends ViewModel {
  StockCountsViewModel([StockCountRepository? repo])
    : _repo = repo ?? StockCountRepository();

  final StockCountRepository _repo;

  /// What a count can be narrowed to; null counts everything on sale.
  static const categories = <String?, String>{
    null: 'Everything',
    'WOMEN': 'Women',
    'MEN': 'Men',
    'KIDS': 'Kids',
    'UNISEX': 'Unisex',
  };

  List<StockCount>? _counts;
  ApiException? _error;
  bool _creating = false;
  String? _createError;
  StockCount? _created;

  /// Null until the first load arrives. Newest first, as the server sends them.
  List<StockCount>? get counts => _counts;

  /// Why the last load failed; a 403 shows as no access.
  ApiException? get error => _error;
  bool get creating => _creating;

  /// The server's message from the last failed [create].
  String? get createError => _createError;

  /// The count [create] made.
  StockCount? get created => _created;

  int get openCount => _counts?.where((c) => c.isOpen).length ?? 0;

  /// stock_count:view
  Future<void> load() async {
    _error = null;
    notifyListeners();
    try {
      _counts = await _repo.stockCounts();
    } on ApiException catch (e) {
      _error = e;
    }
    notifyListeners();
  }

  /// stock_count:create. Null on success (see [created]), otherwise the server's message.
  Future<String?> create({
    required String name,
    required String locationId,
    String? category,
  }) async {
    _creating = true;
    _createError = null;
    notifyListeners();
    try {
      _created = await _repo.createStockCount(
        name: name,
        locationId: locationId,
        category: category,
      );
      return null;
    } on ApiException catch (e) {
      _createError = e.message;
      return e.message;
    } finally {
      _creating = false;
      notifyListeners();
    }
  }
}
