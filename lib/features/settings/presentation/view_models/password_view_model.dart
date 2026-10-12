import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/view_model/view_model.dart';
import 'package:scaleezy/features/settings/data/account_repository.dart';

/// The change-password sheet: checks the new password, sends it, and holds what went wrong.
class PasswordViewModel extends ViewModel {
  PasswordViewModel([AccountRepository? account])
    : _account = account ?? AccountRepository();

  final AccountRepository _account;

  bool _busy = false;
  String? _error;

  bool get busy => _busy;
  String? get error => _error;

  /// Null once changed, otherwise why not.
  Future<String?> change(String current, String next, String again) async {
    if (next.length < 8) {
      return _fail('The new password must be at least 8 characters.');
    }
    if (next != again) return _fail('The two new passwords do not match.');
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _account.changeMyPassword(current, next);
    } on ApiException catch (e) {
      _error = e.message;
    }
    _busy = false;
    notifyListeners();
    return _error;
  }

  String _fail(String message) {
    _error = message;
    notifyListeners();
    return message;
  }
}
