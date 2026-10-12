import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/view_model/view_model.dart';
import 'package:scaleezy/features/shelves/data/shelf_models.dart';
import 'package:scaleezy/features/shelves/data/shelf_repository.dart';

/// One shelf and the pieces on it.
class SpotViewModel extends ViewModel {
  SpotViewModel(this.spotId, [ShelfRepository? repo])
    : _repo = repo ?? ShelfRepository();

  final String spotId;
  final ShelfRepository _repo;

  SpotContents? _spot;
  ApiException? _error;
  String? _warning;

  /// Null until the first load arrives.
  SpotContents? get spot => _spot;
  ApiException? get error => _error;

  /// What the server cautioned about on the last successful [move], if anything.
  String? get warning => _warning;

  /// shelf:view
  Future<void> load() async {
    _error = null;
    notifyListeners();
    try {
      final s = await _repo.spot(spotId);
      if (disposed) return;
      _spot = s;
    } on ApiException catch (e) {
      if (disposed) return;
      _error = e;
    }
    notifyListeners();
  }

  /// shelf:putaway. Moves [quantity] of [item] to [to], or off the shelf when [to] is null.
  /// Null when it worked (the shelf then reloads), else the server's message.
  Future<String?> move(ShelfItem item, ShelfSpot? to, int quantity) async {
    final s = _spot!;
    try {
      final warning = await _repo.moveOnShelves(
        locationId: s.locationId,
        variantId: item.variantId,
        fromSpotId: s.spotId,
        toSpotId: to?.id,
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
