import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/features/team/data/team_models.dart';

void main() {
  test('team member roles flatten', () {
    final m = TeamMember.fromJson({
      'id': 'u1',
      'name': 'Asha',
      'email': 'a@b.c',
      'status': 'ACTIVE',
      'roles': [
        {
          'role': {'id': 'r', 'name': 'Manager'},
        },
      ],
    });
    expect(m.roles, ['Manager']);
  });
}
