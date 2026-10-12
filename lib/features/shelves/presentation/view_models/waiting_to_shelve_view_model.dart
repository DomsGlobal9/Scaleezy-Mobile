import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/view_model/view_model.dart';
import 'package:scaleezy/features/shelves/data/shelf_models.dart';
import 'package:scaleezy/features/shelves/data/shelf_repository.dart';

/// Pieces in one store that are not on any shelf yet.
class WaitingToShelveViewModel extends ViewModel {
  WaitingToShelveViewModel(this.locationId, [ShelfRepository? repo])
    : _repo = repo ?? ShelfRepository();

  final String locationId;
  final ShelfRepository _repo;

  List<NotShelvedItem>? _items;
  ApiException? _error;
  String? _warning;

  /// Null until the first load arrives.
  List<NotShelvedItem>? get items => _items;
  ApiException? get error => _error;

  /// What the server cautioned about on the last successful [putAway], if anything.
  String? get warning => _warning;

  /// Pieces still waiting, across every item.
  int get waiting => _items?.fold<int>(0, (a, n) => a + n.notShelved) ?? 0;

  /// shelf:view
  Future<void> load() async {
    _error = null;
    notifyListeners();
    try {
      final items = await _repo.notShelved(locationId);
      if (disposed) return;
      _items = items;
    } on ApiException catch (e) {
      if (disposed) return;
      _error = e;
    }
    notifyListeners();
  }

  /// shelf:putaway. Puts [quantity] of [n] onto [to].
  /// Null when it worked (the list then reloads), else the server's message.
  Future<String?> putAway(NotShelvedItem n, ShelfSpot to, int quantity) async {
    try {
      final warning = await _repo.putAway(
        locationId: locationId,
        variantId: n.item.variantId,
        spotId: to.id,
        quantity: quantity,
      );
      if (disposed) return null;
      _warning = warning;
      load();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }
}
