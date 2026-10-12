import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/network/api_endpoints.dart';
import 'package:scaleezy/core/utils/json_parse.dart';
import 'package:scaleezy/features/team/data/team_models.dart';

/// The people on the team. Permissions noted per call.
class TeamRepository {
  TeamRepository([ApiClient? client]) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  /// admin:users
  Future<List<TeamMember>> team() async => asMaps(
    dataOf(await _api.get(ApiEndpoints.teamMembers)),
  ).map(TeamMember.fromJson).toList();
}
