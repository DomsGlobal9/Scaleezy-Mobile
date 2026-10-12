import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/shop/shop_models.dart';
import 'package:scaleezy/core/view_model/view_model.dart';
import 'package:scaleezy/features/shelves/data/shelf_models.dart';
import 'package:scaleezy/features/shelves/data/shelf_repository.dart';

/// The shelves overview: one store's racks and shelves, and how much of its stock is on them.
class ShelvesViewModel extends ViewModel {
  ShelvesViewModel([ShelfRepository? repo]) : _repo = repo ?? ShelfRepository();

  final ShelfRepository _repo;

  StockLocation? _location;
  ShelfTree? _tree;
  String? _error;
  SpotContents? _scanned;

  /// Null until a store is known.
  StockLocation? get location => _location;

  /// Null until the first load arrives.
  ShelfTree? get tree => _tree;
  String? get error => _error;

  /// The shelf the last successful [scanLabel] found.
  SpotContents? get scanned => _scanned;

  /// Online shops have no shelves.
  static List<StockLocation> storesOf(List<StockLocation> locations) =>
      locations.where((l) => l.type != 'ONLINE').toList();

  /// Opens on the selected store, else the first real store, else whatever there is.
  void start(StockLocation? selected, List<StockLocation> locations) {
    _location =
        selected ?? storesOf(locations).firstOrNull ?? locations.firstOrNull;
    load();
  }

  /// shelf:view
  Future<void> load() async {
    final loc = _location;
    if (loc == null) {
      _error = 'No store is set up yet, so there are no shelves to show.';
      notifyListeners();
      return;
    }
    _error = null;
    notifyListeners();
    try {
      final tree = await _repo.shelfTree(loc.id);
      if (disposed) return;
      _tree = tree;
    } on ApiException catch (e) {
      if (disposed) return;
      _error = e.message;
    }
    notifyListeners();
  }

  void pickLocation(StockLocation location) {
    if (location.id == _location?.id) return;
    _location = location;
    _tree = null;
    load();
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
