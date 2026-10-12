import 'package:scaleezy/core/utils/json_parse.dart';

class TeamMember {
  final String id;
  final String name;
  final String email;
  final String status;
  final List<String> roles;
  final DateTime? lastActiveAt;

  const TeamMember({
    required this.id,
    required this.name,
    required this.email,
    required this.status,
    required this.roles,
    this.lastActiveAt,
  });

  factory TeamMember.fromJson(Map<String, dynamic> j) => TeamMember(
    id: asString(j['id']),
    name: asOptString(j['name']) ?? asString(j['email']),
    email: asString(j['email']),
    status: asString(j['status']),
    roles: asMaps(j['roles'])
        .map((r) => asString(asMap(r['role'])['name']))
        .where((n) => n.isNotEmpty)
        .toList(),
    lastActiveAt: asDate(j['lastActiveAt']) ?? asDate(j['lastLoginAt']),
  );
}
