import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/features/auth/presentation/login_screen.dart';

import 'auth_fakes.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    AuthSession session, {
    ThemeData? theme,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.light,
        home: SessionScope(session: session, child: const LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> signIn(
    WidgetTester tester,
    String email,
    String password,
  ) async {
    await tester.enterText(find.byType(TextField).first, email);
    await tester.enterText(find.byType(TextField).last, password);
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
  }

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets(
      'checks the fields in the website words (${theme.brightness.name})',
      (tester) async {
        final session = FakeAuthSession();
        await pump(tester, session, theme: theme);
        expect(find.text('Sign in to your shop'), findsOneWidget);

        await signIn(tester, '', '');
        expect(
          find.text('Enter the email address you signed up with.'),
          findsOneWidget,
        );
        await signIn(tester, 'asha', '');
        expect(
          find.text('That does not look like an email address.'),
          findsOneWidget,
        );
        await signIn(tester, 'asha@shop.in', '');
        expect(find.text('Enter your password.'), findsOneWidget);
        expect(session.logins, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('forgot password says who to ask', (tester) async {
    await pump(tester, FakeAuthSession());
    await tester.tap(find.text('Forgot your password?'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Ask your shop owner or manager'),
      findsOneWidget,
    );
  });

  testWidgets('picking a workspace signs in to it; a refusal shows inline', (
    tester,
  ) async {
    final session = FakeAuthSession(
      answer: (clientId) async {
        if (clientId == null) {
          throw const WorkspaceChoiceRequired('Choose a shop.', ['a', 'b']);
        }
        throw const ApiException('This shop is closed.');
      },
    );
    await pump(tester, session);

    await signIn(tester, 'asha@shop.in', 'secret');
    expect(find.textContaining('more than one shop'), findsOneWidget);

    await tester.tap(find.text('b'));
    await tester.pumpAndSettle();
    expect(session.logins.last, ('asha@shop.in', 'secret', 'b'));
    expect(find.text('This shop is closed.'), findsOneWidget);
  });
}
