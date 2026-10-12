import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/utils/json_parse.dart';
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
      if (e.statusCode == 409 && stored != null) {
        final holder = _named(e) ?? await _lookUp(stored);
        _taken = holder?.id == existing?.id ? null : holder;
      }
      _busy = false;
      _error = e.message;
      notifyListeners();
      return e.message;
    }
  }

  /// The holder the server's 409 names: at the top of its body from the customer routes, or in
  /// `details` (code PHONE_TAKEN) from routes that answer through respondWithError.
  static Customer? _named(ApiException e) {
    String? field(String key) =>
        asOptString(e.body?[key]) ?? asOptString(e.details?[key]);
    final id = field('existingCustomerId');
    if (id == null) return null;
    return Customer.fromJson({
      'id': id,
      'name': field('existingCustomerName'),
      'customerCode': field('existingCustomerCode'),
    });
  }

  // Only when the answer did not name them (an older server).
  Future<Customer?> _lookUp(String phone) async {
    try {
      return await _repo.customerByPhone(phone);
    } on ApiException {
      return null;
    }
  }
}
