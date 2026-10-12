import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/shop/shop_models.dart';
import 'package:scaleezy/core/view_model/view_model.dart';
import 'package:scaleezy/features/picking/data/picking_models.dart';
import 'package:scaleezy/features/picking/data/picking_repository.dart';

/// The orders waiting to go out from one store, and which of them to pick together.
class PickOrdersViewModel extends ViewModel {
  PickOrdersViewModel([PickingRepository? repo])
    : _repo = repo ?? PickingRepository();

  final PickingRepository _repo;

  /// The server makes one walk for at most this many orders.
  static const maxOrders = 30;

  StockLocation? _location;
  List<PickOrder>? _orders;
  String? _error;
  final List<String> _selected = [];

  /// Null until a store is known.
  StockLocation? get location => _location;

  /// Null until the first load arrives.
  List<PickOrder>? get orders => _orders;
  String? get error => _error;
  List<String> get selected => List.unmodifiable(_selected);
  bool isSelected(String id) => _selected.contains(id);

  /// Same rule as the shelves: the selected store, else the first that is not online.
  void start(StockLocation? selected, List<StockLocation> locations) {
    _location =
        selected ??
        locations.where((l) => l.type != 'ONLINE').firstOrNull ??
        locations.firstOrNull;
    load();
  }

  /// shelf:putaway
  Future<void> load() async {
    final loc = _location;
    if (loc == null) {
      _error = 'No store is set up yet, so there are no orders to pick.';
      notifyListeners();
      return;
    }
    _error = null;
    notifyListeners();
    try {
      final orders = await _repo.pickOrders(loc.id);
      if (disposed) return;
      _orders = orders;
      // Orders that went out meanwhile cannot stay chosen.
      _selected.removeWhere((id) => !orders.any((o) => o.id == id));
    } on ApiException catch (e) {
      if (disposed) return;
      _error = e.message;
    }
    notifyListeners();
  }

  void toggle(String id) {
    if (!_selected.remove(id) && _selected.length < maxOrders) {
      _selected.add(id);
    }
    notifyListeners();
  }

  /// Chooses the oldest [maxOrders], or clears the choice when some are chosen.
  void selectAllOrClear() {
    if (_selected.isNotEmpty) {
      _selected.clear();
    } else {
      _selected.addAll((_orders ?? []).take(maxOrders).map((o) => o.id));
    }
    notifyListeners();
  }

  /// After the chosen orders went out.
  void clearSelection() {
    _selected.clear();
    load();
  }
}
