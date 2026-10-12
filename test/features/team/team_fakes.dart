import 'package:scaleezy/features/team/data/team_models.dart';
import 'package:scaleezy/features/team/data/team_repository.dart';

import '../../support/fake_api.dart';

export '../../support/fake_api.dart' show offlineClient;

TeamMember member(
  String id, {
  String name = 'Meena',
  String status = 'ACTIVE',
  DateTime? lastActiveAt,
}) => TeamMember(
  id: id,
  name: name,
  email: '$id@shop.in',
  status: status,
  roles: const ['STORE_MANAGER'],
  lastActiveAt: lastActiveAt,
);

class FakeTeamRepository extends TeamRepository {
  FakeTeamRepository(this.answer) : super(offlineClient());

  Future<List<TeamMember>> Function() answer;
  int calls = 0;

  @override
  Future<List<TeamMember>> team() {
    calls++;
    return answer();
  }
}
