import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/view_model/view_model.dart';
import 'package:scaleezy/features/customers/data/customer_models.dart';
import 'package:scaleezy/features/customers/data/customer_repository.dart';

/// One customer in full, with their recent orders, points and store credit.
class CustomerDetailViewModel extends ViewModel {
  CustomerDetailViewModel(this.customerId, [CustomerRepository? repo])
    : _repo = repo ?? CustomerRepository();

  final String customerId;
  final CustomerRepository _repo;

  Customer? _full;
  String? _error;
  CustomerPoints? _points;
  StoreCredit? _credit;

  /// Null until the first load arrives.
  Customer? get full => _full;
  String? get error => _error;

  /// Null when there is nothing to show: loyalty off and never used, not
  /// allowed, failed, or not arrived yet. Never holds up the customer.
  CustomerPoints? get points => _points?.worthShowing == true ? _points : null;
  StoreCredit? get credit => _credit?.worthShowing == true ? _credit : null;

  Future<void> load() async {
    _error = null;
    notifyListeners();
    await Future.wait([_loadCustomer(), _loadPoints(), _loadCredit()]);
  }

  Future<void> _loadCustomer() async {
    try {
      _full = await _repo.customer(customerId);
    } on ApiException catch (e) {
      _error = e.message;
    }
    notifyListeners();
  }

  Future<void> _loadPoints() async {
    try {
      _points = await _repo.customerPoints(customerId);
      notifyListeners();
    } on ApiException {
      // Fails soft: keeps what was there, or shows nothing.
    }
  }

  Future<void> _loadCredit() async {
    try {
      _credit = await _repo.storeCredit(customerId);
      notifyListeners();
    } on ApiException {
      // Fails soft: keeps what was there, or shows nothing.
    }
  }
}
