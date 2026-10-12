import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/features/team/presentation/view_models/team_view_model.dart';

import 'team_fakes.dart';

void main() {
  test('active people first, most recently seen first', () async {
    final now = DateTime.now();
    final vm = TeamViewModel(
      FakeTeamRepository(
        () async => [
          member('old', lastActiveAt: now.subtract(const Duration(days: 2))),
          member('gone', status: 'SUSPENDED', lastActiveAt: now),
          member('never'),
          member('now', lastActiveAt: now.subtract(const Duration(minutes: 3))),
        ],
      ),
    );
    expect(vm.members, isNull);

    await vm.load();
    expect(vm.members!.map((m) => m.id), ['now', 'old', 'never', 'gone']);
    expect(vm.activeNow, 2); // 'now' and the suspended one seen just now
  });

  test('a failure shows the server message, a retry clears it', () async {
    var fail = true;
    final repo = FakeTeamRepository(
      () async => fail ? throw const ApiException('No access.') : [member('a')],
    );
    final vm = TeamViewModel(repo);

    await vm.load();
    expect(vm.error, 'No access.');
    expect(vm.members, isNull);

    fail = false;
    await vm.load();
    expect(vm.error, isNull);
    expect(vm.members, hasLength(1));
    expect(repo.calls, 2);
  });
}
