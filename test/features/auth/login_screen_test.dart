import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/features/auth/presentation/login_screen.dart';

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
}
