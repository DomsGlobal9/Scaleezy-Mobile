import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/view_model/view_model.dart';

/// Signing in: whether a sign-in is on its way, the server's complaint, and the workspaces to
/// choose from when one email and password belong to more than one shop.
class LoginViewModel extends ViewModel {
  LoginViewModel(this._session);

  final AuthSession _session;

  bool _submitting = false;
  String? _error;
  WorkspaceChoiceRequired? _workspaceChoice;

  bool get submitting => _submitting;
  String? get error => _error;

  /// Set when the last sign-in needs a workspace picked; submit again with its clientId.
  WorkspaceChoiceRequired? get workspaceChoice => _workspaceChoice;

  /// "Back" from the workspace list to the form.
  void cancelWorkspaceChoice() {
    _workspaceChoice = null;
    notifyListeners();
  }

  /// The website's own checks before asking the server, in its words; null when both look
  /// fine. Deliberately forgiving: the server decides whether an address exists.
  static String? check(String email, String password) {
    final address = email.trim();
    if (address.isEmpty) return 'Enter the email address you signed up with.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(address)) {
      return 'That does not look like an email address.';
    }
    if (password.isEmpty) return 'Enter your password.';
    return null;
  }

  /// Null when signed in or a workspace must be picked, otherwise what went wrong: a field
  /// [check] refused, or the server's message.
  Future<String?> submit(
    String email,
    String password, {
    String? clientId,
  }) async {
    final problem = check(email, password);
    if (problem != null) {
      _error = problem;
      _workspaceChoice = null;
      notifyListeners();
      return problem;
    }
    _submitting = true;
    _error = null;
    _workspaceChoice = null;
    notifyListeners();
    try {
      await _session.login(email, password, clientId: clientId);
      // The router redirects to the app when the session changes.
    } on WorkspaceChoiceRequired catch (e) {
      _workspaceChoice = e;
    } on ApiException catch (e) {
      _error = e.message;
    }
    _submitting = false;
    notifyListeners();
    return _error;
  }
}
