import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/features/auth/presentation/login_screen.dart';

import 'auth_fakes.dart';

void main() {
  testWidgets('login screen renders and validates empty fields', (
    tester,
  ) async {
    final session = AuthSession(ApiClient.withDio(Dio()));
    await tester.pumpWidget(
      MaterialApp(
        home: SessionScope(session: session, child: const LoginScreen()),
      ),
    );

    await tester.pumpAndSettle(); // let the entrance animation finish
    expect(find.text('Sign in to ScaleEzy'), findsOneWidget);
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
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
    await tester.pumpWidget(
      MaterialApp(
        home: SessionScope(session: session, child: const LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'asha@shop.in');
    await tester.enterText(find.byType(TextFormField).last, 'secret');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a shop.'), findsOneWidget);

    await tester.tap(find.text('b'));
    await tester.pumpAndSettle();
    expect(session.logins.last, ('asha@shop.in', 'secret', 'b'));
    expect(find.text('This shop is closed.'), findsOneWidget);
  });
}
