import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/view_model/view_model.dart';
import 'package:scaleezy/features/suppliers/data/supplier_models.dart';
import 'package:scaleezy/features/suppliers/data/supplier_repository.dart';

/// Every supplier, inactive ones included (labelled, as on the website), with a text search.
class SuppliersViewModel extends ViewModel {
  SuppliersViewModel([SupplierRepository? repo])
    : _repo = repo ?? SupplierRepository();

  final SupplierRepository _repo;

  List<Supplier>? _all;
  ApiException? _failure;
  String _query = '';

  /// Null until the first load arrives.
  List<Supplier>? get all => _all;
  String? get error => _failure?.message;

  /// The last failed load, kept whole so a 403 shows as no access.
  ApiException? get failure => _failure;
  String get query => _query;

  Future<void> load() async {
    _failure = null;
    notifyListeners();
    try {
      _all = await _repo.suppliers();
    } on ApiException catch (e) {
      _failure = e;
    }
    notifyListeners();
  }

  void search(String text) {
    _query = text;
    notifyListeners();
  }

  /// The suppliers that match the search.
  List<Supplier> get visible {
    final q = _query.trim().toLowerCase();
    return (_all ?? const <Supplier>[])
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
