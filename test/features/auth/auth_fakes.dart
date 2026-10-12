import 'package:dio/dio.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/session/auth_user.dart';

/// A client that is never called: the fakes below answer instead.
ApiClient offlineClient() => ApiClient.withDio(Dio());

AuthUser person({bool owner = false}) => AuthUser(
  id: 'u1',
  clientId: 'shop-1',
  name: 'Asha',
  email: 'asha@shop.in',
  roles: [owner ? 'Owner' : 'Staff'],
  permissions: owner ? {'*'} : {'products:view'},
);

/// Records each login, restore and logout; [answer] decides how a login ends.
class FakeAuthSession extends AuthSession {
  FakeAuthSession({this.signedIn, this.answer}) : super(offlineClient());

  AuthUser? signedIn;
  Future<void> Function(String? clientId)? answer;
  final logins = <(String, String, String?)>[];
  int restores = 0;
  int logouts = 0;

  @override
  AuthUser? get user => signedIn;

  @override
  Future<void> login(String email, String password, {String? clientId}) {
    logins.add((email, password, clientId));
    return answer?.call(clientId) ?? Future.value();
  }

  @override
  Future<void> restore() async => restores++;

  @override
  Future<void> logout() async => logouts++;
}
