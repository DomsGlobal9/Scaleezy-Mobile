import 'dart:async';

import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/view_model/view_model.dart';
import 'package:scaleezy/features/shelves/data/shelf_models.dart';
import 'package:scaleezy/features/shelves/data/shelf_repository.dart';

/// "Where is it?": which shelves a piece is on, searched by name, SKU or barcode in the
/// selected store, or in every location when asked (the website's `WhereIsIt`).
class FindPieceViewModel extends ViewModel {
  FindPieceViewModel({this.locationId, ShelfRepository? repo})
    : _repo = repo ?? ShelfRepository();

  /// The app's selected store: searched alone unless [everywhere], and listed first.
  String? locationId;
  final ShelfRepository _repo;

  List<WhereItem>? _results;
  bool _loading = false;
  ApiException? _error;
  bool _everywhere = false;
  String _query = '';
  int _requestId = 0;
  Timer? _debounce;

  /// Null while nothing has been searched.
  List<WhereItem>? get results => _results;
  bool get loading => _loading;
  ApiException? get error => _error;

  /// "Look in every location", not just [locationId].
  bool get everywhere => _everywhere;

  /// The text the results are for.
  String get query => _query;

  /// Typing searches once the person pauses.
  void typed(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => search(q));
  }

  /// Searches [text] (what is in the box now) again in every location, or in this store only.
  void setEverywhere(bool value, String text) {
    if (value == _everywhere) return;
    _everywhere = value;
    search(text);
  }

  /// shelf:view
  Future<void> search(String q) async {
    _debounce?.cancel();
    final id = ++_requestId;
    _query = q.trim();
    if (_query.isEmpty) {
      _results = null;
      _error = null;
      _loading = false;
      notifyListeners();
      return;
    }
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final r = await _repo.findOnShelves(
        _query,
        locationId: _everywhere ? null : locationId,
      );
      // A newer search started meanwhile; this answer is for old text.
      if (disposed || id != _requestId) return;
      _results = r;
    } on ApiException catch (e) {
      if (disposed || id != _requestId) return;
      _error = e;
    }
    _loading = false;
    notifyListeners();
  }

  /// This store's places first, then the rest.
  List<WherePlace> placesOf(WhereItem w) => locationId == null
      ? w.places
      : [
          ...w.places.where((p) => p.locationId == locationId),
          ...w.places.where((p) => p.locationId != locationId),
        ];

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
