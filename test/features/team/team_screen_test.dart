import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/features/team/presentation/team_screen.dart';
import 'package:scaleezy/features/team/presentation/view_models/team_view_model.dart';

import 'team_fakes.dart';

void main() {
  testWidgets('team screen shows what its view model loads', (tester) async {
    final vm = TeamViewModel(
      FakeTeamRepository(
        () async => [
          member('a', name: 'Meena', lastActiveAt: DateTime.now()),
          member('b', name: 'Arjun'),
        ],
      ),
    );
    await tester.pumpWidget(
      SessionScope(
        session: AuthSession(offlineClient()),
        child: MaterialApp(home: TeamScreen(viewModel: vm)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Meena'), findsOneWidget);
    expect(find.text('Arjun'), findsOneWidget);
    expect(find.text('2 people • 1 active now'), findsOneWidget);
  });
}
