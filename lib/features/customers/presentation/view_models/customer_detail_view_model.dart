import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/view_model/view_model.dart';
import 'package:scaleezy/features/customers/data/customer_models.dart';
import 'package:scaleezy/features/customers/data/customer_repository.dart';

/// One customer in full, with their recent orders.
class CustomerDetailViewModel extends ViewModel {
  CustomerDetailViewModel(this.customerId, [CustomerRepository? repo])
    : _repo = repo ?? CustomerRepository();

  final String customerId;
  final CustomerRepository _repo;

  Customer? _full;
  String? _error;

  /// Null until the first load arrives.
  Customer? get full => _full;
  String? get error => _error;

  Future<void> load() async {
    _error = null;
    notifyListeners();
    try {
      _full = await _repo.customer(customerId);
    } on ApiException catch (e) {
      _error = e.message;
    }
    notifyListeners();
  }
}
