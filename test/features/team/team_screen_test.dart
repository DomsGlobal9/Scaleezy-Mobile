import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/features/team/presentation/team_screen.dart';
import 'package:scaleezy/features/team/presentation/view_models/team_view_model.dart';

import 'team_fakes.dart';

void main() {
  for (final (name, theme) in [
    ('light', AppTheme.light),
    ('dark', AppTheme.dark),
  ]) {
    testWidgets('team screen shows what it loads ($name theme)', (
      tester,
    ) async {
      final vm = TeamViewModel(
        FakeTeamRepository(
          () async => [
            member('a', name: 'Meena', lastActiveAt: DateTime.now()),
            member('b', name: 'Arjun', status: 'SUSPENDED'),
          ],
        ),
      );
      await tester.pumpWidget(
        SessionScope(
          session: AuthSession(offlineClient()),
          child: MaterialApp(
            theme: theme,
            home: TeamScreen(viewModel: vm),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(find.text('Meena'), findsOneWidget);
      expect(find.text('Arjun'), findsOneWidget);
      expect(find.text('2 people • 1 active now'), findsOneWidget);
      // Roles and statuses in words, never the stored value.
      expect(find.text('Store Manager · active now'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Suspended'), findsOneWidget);
    });
  }
}
