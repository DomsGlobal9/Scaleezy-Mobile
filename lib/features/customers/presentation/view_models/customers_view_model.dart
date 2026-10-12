import 'dart:async';

import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/view_model/view_model.dart';
import 'package:scaleezy/features/customers/data/customer_models.dart';
import 'package:scaleezy/features/customers/data/customer_repository.dart';

/// Everyone who has bought from the shop, with a search box.
class CustomersViewModel extends ViewModel {
  CustomersViewModel([CustomerRepository? repo])
    : _repo = repo ?? CustomerRepository();

  final CustomerRepository _repo;

  String _query = '';
  List<Customer>? _customers;
  String? _error;
  int _requestId = 0;
  Timer? _debounce;

  String get query => _query;

  /// Null until the first load arrives.
  List<Customer>? get customers => _customers;
  String? get error => _error;

  Future<void> load() async {
    final id = ++_requestId;
    _error = null;
    notifyListeners();
    try {
      final list = await _repo.customers(search: _query);
      // A newer search started meanwhile; this answer is stale.
      if (disposed || id != _requestId) return;
      _customers = list;
    } on ApiException catch (e) {
      if (disposed || id != _requestId) return;
      _error = e.message;
    }
    notifyListeners();
  }

  /// Typing searches once the person pauses.
  void search(String text) {
    _query = text;
    notifyListeners();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), load);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
