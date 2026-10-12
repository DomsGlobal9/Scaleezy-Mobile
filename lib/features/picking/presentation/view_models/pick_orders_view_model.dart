import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/shop/shop_models.dart';
import 'package:scaleezy/core/view_model/view_model.dart';
import 'package:scaleezy/features/picking/data/picking_models.dart';
import 'package:scaleezy/features/picking/data/picking_repository.dart';

/// The orders waiting to go out from the selected store, and which of them to pick together.
class PickOrdersViewModel extends ViewModel {
  PickOrdersViewModel([PickingRepository? repo])
    : _repo = repo ?? PickingRepository();

  final PickingRepository _repo;

  /// The server makes one walk for at most this many orders.
  static const maxOrders = 30;

  StockLocation? _location;
  List<PickOrder>? _orders;
  ApiException? _error;
  final List<String> _selected = [];
  int _requestId = 0;

  /// The app's selected store; null until the shop knows it.
  StockLocation? get location => _location;

  /// Null until the first load arrives.
  List<PickOrder>? get orders => _orders;
  ApiException? get error => _error;
  List<String> get selected => List.unmodifiable(_selected);
  bool isSelected(String id) => _selected.contains(id);

  /// Shows [location] (the app's selected store); another store starts with nothing chosen.
  void show(StockLocation? location) {
    if (location?.id != _location?.id) {
      _orders = null;
      _selected.clear();
    }
    _location = location;
    load();
  }

  /// shelf:putaway
  Future<void> load() async {
    // Switching store mid-load starts another load; only the newest one may land.
    final id = ++_requestId;
    final loc = _location;
    _error = null;
    notifyListeners();
    if (loc == null) return;
    try {
      final orders = await _repo.pickOrders(loc.id);
      if (disposed || id != _requestId) return;
      _orders = orders;
      // Orders that went out meanwhile cannot stay chosen.
      _selected.removeWhere((s) => !orders.any((o) => o.id == s));
    } on ApiException catch (e) {
      if (disposed || id != _requestId) return;
      _error = e;
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
