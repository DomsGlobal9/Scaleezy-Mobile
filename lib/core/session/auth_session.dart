import 'package:flutter/widgets.dart';

import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/network/api_endpoints.dart';
import 'package:scaleezy/core/session/auth_user.dart';

/// Thrown when one email + password matches accounts in more than one shop.
class WorkspaceChoiceRequired implements Exception {
  final String message;
  final List<String> clientIds;
  const WorkspaceChoiceRequired(this.message, this.clientIds);
}

enum AuthStatus { unknown, signedOut, signedIn }

/// Who is signed in. The token itself lives in the cookie jar; this only holds the user.
class AuthSession extends ChangeNotifier {
  AuthSession(this._api) {
    _api.onUnauthorized = _expire;
  }

  final ApiClient _api;

  AuthStatus _status = AuthStatus.unknown;
  AuthUser? _user;
  String? _restoreError;
  bool _signedOutOnPurpose = false;

  AuthStatus get status => _status;
  AuthUser? get user => _user;

  /// Set while the status stays unknown because the server could not be asked at start (not a
  /// 401): the saved session is kept and the splash offers to [restore] again.
  String? get restoreError => _restoreError;

  /// True after the person pressed Sign out, so nothing of theirs (where they were, their
  /// store) is kept for whoever signs in next. False after an expired session.
  bool get signedOutOnPurpose => _signedOutOnPurpose;

  bool can(String permission) => _user?.can(permission) ?? false;

  /// App start: is the saved cookie still good?
  Future<void> restore() async {
    if (_restoreError != null) {
      _restoreError = null;
      notifyListeners();
    }
    try {
      final body = await _api.get(ApiEndpoints.session);
      if (body is Map && body['authenticated'] == true && body['user'] is Map) {
        final client = body['client'] is Map ? body['client'] as Map : const {};
        _set(
          AuthUser.fromJson(
            Map<String, dynamic>.from(body['user']),
            clientId: client['id'] as String?,
          ),
        );
        return;
      }
    } on ApiException catch (e) {
      // Only the server saying no ends the session; a phone without signal keeps it.
      if (!e.isUnauthorized) {
        _restoreError = e.message;
        notifyListeners();
        return;
      }
    }
    _set(null);
  }

  Future<void> login(String email, String password, {String? clientId}) async {
    final body = await _api.post(
      ApiEndpoints.login,
      body: {
        'email': email.trim(),
        'password': password,
        'clientId': ?clientId,
      },
      acceptUnsuccessful: true,
    );

    if (body is Map && body['requiresWorkspaceSelection'] == true) {
      final ids = (body['workspaces'] as List? ?? const [])
          .whereType<Map>()
          .map((w) => w['clientId']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      throw WorkspaceChoiceRequired(
        body['message']?.toString() ?? 'Choose a workspace.',
        ids,
      );
    }
    if (body is Map && body['success'] == false) {
      throw ApiException(body['message']?.toString() ?? 'Sign-in failed.');
    }

    final user = dataOf(body) is Map ? (dataOf(body) as Map)['user'] : null;
    if (user is! Map) {
      throw const ApiException(
        'Sign-in answered in a way the app does not understand.',
      );
    }
    _set(AuthUser.fromJson(Map<String, dynamic>.from(user)));
  }

  Future<void> logout() async {
    try {
      await _api.post(ApiEndpoints.logout);
    } on ApiException {
      // Signing out locally still matters if the server is unreachable.
    }
    _set(null, onPurpose: true);
  }

  void _expire() {
    if (_status == AuthStatus.signedIn) _set(null);
  }

  void _set(AuthUser? user, {bool onPurpose = false}) {
    _user = user;
    _signedOutOnPurpose = onPurpose;
    _status = user == null ? AuthStatus.signedOut : AuthStatus.signedIn;
    notifyListeners();
  }
}

/// Makes the session reachable from any screen: `SessionScope.of(context).can('...')`.
class SessionScope extends InheritedNotifier<AuthSession> {
  const SessionScope({
    super.key,
    required AuthSession session,
    required super.child,
  }) : super(notifier: session);

  static AuthSession of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SessionScope>()!.notifier!;

  /// Without subscribing to changes -- safe from initState and callbacks.
  static AuthSession read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SessionScope>()!.notifier!;
}
