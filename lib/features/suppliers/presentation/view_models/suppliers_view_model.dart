import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/view_model/view_model.dart';
import 'package:scaleezy/features/suppliers/data/supplier_models.dart';
import 'package:scaleezy/features/suppliers/data/supplier_repository.dart';

/// Suppliers with a text search and an option to include inactive ones.
class SuppliersViewModel extends ViewModel {
  SuppliersViewModel([SupplierRepository? repo])
    : _repo = repo ?? SupplierRepository();

  final SupplierRepository _repo;

  List<Supplier>? _all;
  String? _error;
  String _query = '';
  bool _showInactive = false;

  /// Null until the first load arrives.
  List<Supplier>? get all => _all;
  String? get error => _error;
  String get query => _query;
  bool get showInactive => _showInactive;

  Future<void> load() async {
    _error = null;
    notifyListeners();
    try {
      _all = await _repo.suppliers();
    } on ApiException catch (e) {
      _error = e.message;
    }
    notifyListeners();
  }

  void search(String text) {
    _query = text;
    notifyListeners();
  }

  void setShowInactive(bool value) {
    _showInactive = value;
    notifyListeners();
  }

  List<Supplier> get _loaded => _all ?? const <Supplier>[];

  int get inactive => _loaded.where((s) => !s.active).length;

  /// The suppliers that match the search, inactive ones only when asked for.
  List<Supplier> get visible {
    final q = _query.trim().toLowerCase();
    return _loaded
        .where((s) => _showInactive || s.active)
        .where(
          (s) =>
              q.isEmpty ||
              '${s.name} ${s.code} ${s.phone ?? ''} ${s.email ?? ''}'
                  .toLowerCase()
                  .contains(q),
        )
        .toList();
  }
}
