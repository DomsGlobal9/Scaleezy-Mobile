import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/view_model/view_model.dart';
import 'package:scaleezy/features/customers/data/customer_models.dart';
import 'package:scaleezy/features/customers/data/customer_repository.dart';

/// Adds a customer, or edits [existing].
class CustomerFormViewModel extends ViewModel {
  CustomerFormViewModel(this.existing, [CustomerRepository? repo])
    : _repo = repo ?? CustomerRepository();

  final Customer? existing;
  final CustomerRepository _repo;

  bool _busy = false;
  String? _error;
  Customer? _saved;

  bool get busy => _busy;

  /// The server's message from the last failed save.
  String? get error => _error;

  /// The customer as the server saved it, once [save] succeeds.
  Customer? get saved => _saved;

  /// customer:create or customer:update. Null on success, otherwise the server's message.
  Future<String?> save({
    required String name,
    required String phone,
    required String email,
  }) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final e = existing;
      _saved = e == null
          ? await _repo.createCustomer(name: name, phone: phone, email: email)
          : await _repo.updateCustomer(
              e.id,
              name: name,
              phone: phone,
              email: email,
            );
      // Stays busy: the form closes on success.
      return null;
    } on ApiException catch (e) {
      _busy = false;
      _error = e.message;
      notifyListeners();
      return e.message;
    }
  }
}
