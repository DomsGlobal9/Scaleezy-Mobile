import 'package:scaleezy/core/utils/json_parse.dart';

class AuthUser {
  final String id;
  final String clientId;
  final String name;
  final String email;
  final List<String> roles;
  final Set<String> permissions;

  const AuthUser({
    required this.id,
    required this.clientId,
    required this.name,
    required this.email,
    required this.roles,
    required this.permissions,
  });

  /// The server has already expanded implied permissions; the owner holds `*`.
  bool can(String permission) =>
      permissions.contains('*') || permissions.contains(permission);

  /// The account owner -- the only one who may change the shop's name and details.
  bool get isOwner => permissions.contains('*');

  /// [clientId] is passed separately for /auth/session, which carries it as `client.id`.
  factory AuthUser.fromJson(Map<String, dynamic> j, {String? clientId}) =>
      AuthUser(
        id: asString(j['id']),
        clientId: asOptString(j['clientId']) ?? clientId ?? '',
        name: asOptString(j['name']) ?? asString(j['email']),
        email: asString(j['email']),
        roles: (j['roles'] as List? ?? const []).map(asString).toList(),
        permissions: (j['permissions'] as List? ?? const [])
            .map(asString)
            .toSet(),
      );
}
