import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/view_model/view_model.dart';
import 'package:scaleezy/features/shelves/data/shelf_models.dart';
import 'package:scaleezy/features/shelves/data/shelf_repository.dart';

/// The move sheet: which shelf pieces go to (or off the shelf) and how many.
class MoveSheetViewModel extends ViewModel {
  MoveSheetViewModel({
    required this.locationId,
    required this.maxQty,
    this.excludeSpotId,
    this.fixedTarget,
    this.requireTarget = false,
    ShelfRepository? repo,
  }) : _repo = repo ?? ShelfRepository(),
       _qty = maxQty {
    final t = fixedTarget;
    if (t != null) _to = _spotOf(t);
  }

  final String locationId;
  final int maxQty;

  /// The shelf the pieces are on now, left out of the choices.
  final String? excludeSpotId;

  /// When set, the pieces can only go here and no list is loaded.
  final SpotContents? fixedTarget;

  /// Putting away needs a shelf, so "off the shelf" is not offered.
  final bool requireTarget;
  final ShelfRepository _repo;

  int _qty;
  ShelfSpot? _to;
  bool _offShelf = false;
  List<ShelfSpot>? _spots;
  String _filter = '';

  int get qty => _qty;
  ShelfSpot? get to => _to;
  bool get offShelf => _offShelf;

  /// True until the list of shelves has arrived.
  bool get loadingSpots => _spots == null;

  /// Shelves that can take pieces, narrowed by the filter text.
  List<ShelfSpot> get spots => (_spots ?? const <ShelfSpot>[])
      .where(
        (s) =>
            _filter.isEmpty ||
            '${s.address} ${s.name ?? ''}'.toLowerCase().contains(
              _filter.toLowerCase(),
            ),
      )
      .toList();

  bool get ready => _qty > 0 && (_to != null || (_offShelf && !requireTarget));

  /// What the sheet hands back: where to (null = off the shelf) and how many.
  (ShelfSpot?, int) get result => (_offShelf ? null : _to, _qty);

  static ShelfSpot _spotOf(SpotContents s) => ShelfSpot(
    id: s.spotId,
    kind: s.kind,
    code: s.address,
    address: s.address,
    name: s.name,
  );

  /// shelf:view. Every shelf in the store that holds pieces, except the one they are on.
  Future<void> load() async {
    if (fixedTarget != null) return;
    try {
      final tree = await _repo.shelfTree(locationId);
      if (disposed) return;
      _spots = tree.spots
          .expand((s) => s.flatten)
          .where((s) => s.holdsStock && s.active && s.id != excludeSpotId)
          .toList();
    } catch (_) {
      // Any failure just leaves nothing to pick; scanning a label still works.
      if (disposed) return;
      _spots = const [];
    }
    notifyListeners();
  }

  void setQty(int qty) {
    _qty = qty;
    notifyListeners();
  }

  void setFilter(String text) {
    _filter = text;
    notifyListeners();
  }

  void takeOffShelf() {
    _offShelf = true;
    _to = null;
    notifyListeners();
  }

  void choose(ShelfSpot spot) {
    _offShelf = false;
    _to = spot;
    notifyListeners();
  }

  /// shelf:view. Picks the shelf whose label was scanned.
  /// Null when it worked, else what to tell the person.
  Future<String?> scanTarget(String code) async {
    final SpotContents spot;
    try {
      spot = await _repo.scanSpot(code, locationId: locationId);
    } on ApiException catch (e) {
      return e.message;
    }
    if (disposed) return null;
    if (!spot.holdsStock) {
      return '${spot.address} holds other shelves. Scan one of those.';
    }
    choose(_spotOf(spot));
    return null;
  }
}
