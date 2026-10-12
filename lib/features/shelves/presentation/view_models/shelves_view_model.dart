import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/shop/shop_models.dart';
import 'package:scaleezy/core/view_model/view_model.dart';
import 'package:scaleezy/features/shelves/data/shelf_models.dart';
import 'package:scaleezy/features/shelves/data/shelf_repository.dart';

/// The shelves overview: the selected store's racks and shelves, and how much of its stock is
/// on them.
class ShelvesViewModel extends ViewModel {
  ShelvesViewModel([ShelfRepository? repo]) : _repo = repo ?? ShelfRepository();

  final ShelfRepository _repo;

  StockLocation? _location;
  ShelfTree? _tree;
  ApiException? _error;
  SpotContents? _scanned;

  /// The app's selected store; null until the shop knows it.
  StockLocation? get location => _location;

  /// Null until the first load arrives.
  ShelfTree? get tree => _tree;
  ApiException? get error => _error;

  /// The shelf the last successful [scanLabel] found.
  SpotContents? get scanned => _scanned;

  /// Shows [location] (the app's selected store), loading it afresh.
  void show(StockLocation? location) {
    if (location?.id != _location?.id) _tree = null;
    _location = location;
    load();
  }

  int _requestId = 0;

  /// shelf:view
  Future<void> load() async {
    // Switching store mid-load starts another load; only the newest one may land.
    final id = ++_requestId;
    final loc = _location;
    _error = null;
    notifyListeners();
    if (loc == null) return;
    try {
      final tree = await _repo.shelfTree(loc.id);
      if (disposed || id != _requestId) return;
      _tree = tree;
    } on ApiException catch (e) {
      if (disposed || id != _requestId) return;
      _error = e;
    }
    notifyListeners();
  }

  /// shelf:view. Looks up a scanned shelf label in this store; the shelf is then [scanned].
  /// Null when it worked, else the server's message.
  Future<String?> scanLabel(String code) async {
    try {
      _scanned = await _repo.scanSpot(code, locationId: _location?.id);
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }
}
