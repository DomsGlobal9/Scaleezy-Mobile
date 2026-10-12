import 'dart:async';

import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/view_model/view_model.dart';
import 'package:scaleezy/features/shelves/data/shelf_models.dart';
import 'package:scaleezy/features/shelves/data/shelf_repository.dart';

/// "Where is it?": which shelves a piece is on, searched by name, SKU or barcode.
class FindPieceViewModel extends ViewModel {
  FindPieceViewModel({this.locationId, ShelfRepository? repo})
    : _repo = repo ?? ShelfRepository();

  /// The store the person came from; its places are listed first.
  final String? locationId;
  final ShelfRepository _repo;

  List<WhereItem>? _results;
  bool _loading = false;
  String? _error;
  int _requestId = 0;
  Timer? _debounce;

  /// Null while nothing has been searched.
  List<WhereItem>? get results => _results;
  bool get loading => _loading;
  String? get error => _error;

  /// Typing searches once the person pauses.
  void typed(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => search(q));
  }

  /// shelf:view. Every store is searched; [placesOf] puts this one first.
  Future<void> search(String q) async {
    final id = ++_requestId;
    if (q.trim().isEmpty) {
      _results = null;
      _loading = false;
      notifyListeners();
      return;
    }
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final r = await _repo.findOnShelves(q);
      // A newer search started meanwhile; this answer is for old text.
      if (disposed || id != _requestId) return;
      _results = r;
    } on ApiException catch (e) {
      if (disposed || id != _requestId) return;
      _error = e.message;
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
