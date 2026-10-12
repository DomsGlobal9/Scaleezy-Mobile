import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/view_model/view_model.dart';
import 'package:scaleezy/features/customers/data/customer_models.dart';
import 'package:scaleezy/features/customers/data/customer_repository.dart';
import 'package:scaleezy/features/customers/data/phone.dart';

/// Adds a customer, or edits [existing].
class CustomerFormViewModel extends ViewModel {
  CustomerFormViewModel(this.existing, [CustomerRepository? repo])
    : _repo = repo ?? CustomerRepository();

  final Customer? existing;
  final CustomerRepository _repo;

  bool _busy = false;
  String? _error;
  Customer? _saved;
  Customer? _taken;

  bool get busy => _busy;

  /// The server's message from the last failed save.
  String? get error => _error;

  /// The customer as the server saved it, once [save] succeeds.
  Customer? get saved => _saved;

  /// Who already has the number, after a save refused for it (409), so the form can offer to
  /// open them.
  Customer? get taken => _taken;

  /// A customer saved before phones were required may be changed without adding one.
  bool get phoneOptional => existing != null && existing!.phone == null;

  /// customer:create or customer:update. The phone is sent in its stored form ("+91…"). Null on
  /// success, otherwise the reason.
  Future<String?> save({
    required String name,
    required String phone,
    required String email,
  }) async {
    final checked = phoneOptional && phone.trim().isEmpty
        ? null
        : normalisePhone(phone);
    _error = checked?.reason ?? emailProblem(email);
    _taken = null;
    if (_error != null) {
      notifyListeners();
      return _error;
    }
    final stored = checked?.value;
    _busy = true;
    notifyListeners();
    try {
      final e = existing;
      _saved = e == null
          ? await _repo.createCustomer(
              name: name,
              phone: stored!,
              email: email.trim(),
            )
          : await _repo.updateCustomer(
              e.id,
              name: name,
              phone: stored,
              email: email.trim(),
            );
      // Stays busy: the form closes on success.
      return null;
    } on ApiException catch (e) {
      if (e.statusCode == 409 && stored != null) _taken = await _holder(stored);
      _busy = false;
      _error = e.message;
      notifyListeners();
      return e.message;
    }
  }

  // The server's 409 names the holder at the top level of its body, which ApiException does not
  // keep, so the number is looked up instead.
  Future<Customer?> _holder(String phone) async {
    try {
      final holder = await _repo.customerByPhone(phone);
      return holder?.id == existing?.id ? null : holder;
    } on ApiException {
      return null;
    }
  }
}
