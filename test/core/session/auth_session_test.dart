import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/session/auth_session.dart';

import '../../support/fake_api.dart';
import '../../support/fixtures.dart';
import '../../support/roles.dart';

/// /auth/session answers with [session]'s result; everything else succeeds.
ApiClient server(FakeHandler session) =>
    (FakeApi(fallback: ok({}))..get('/auth/session', session)).client;

const _signedIn = {
  'authenticated': true,
  'user': {'id': 'u1', 'name': 'Asha', 'email': 'a@b.in'},
  'client': {'id': 'shop-1'},
};

void main() {
  test('an unreachable server at start keeps the saved session', () async {
    var online = false;
    final session = AuthSession(server((_) => online ? _signedIn : offline()));

    await session.restore();
    expect(session.status, AuthStatus.unknown);
    expect(session.restoreError, contains('Could not reach the server'));

    online = true;
    await session.restore();
    expect(session.status, AuthStatus.signedIn);
    expect(session.restoreError, isNull);
    expect(session.user?.clientId, 'shop-1');
  });

  test('a 401 at start asks to sign in, not on purpose', () async {
    final session = AuthSession(server((_) => unauthorized('Not signed in.')));
    await session.restore();
    expect(session.status, AuthStatus.signedOut);
    expect(session.restoreError, isNull);
    expect(session.signedOutOnPurpose, isFalse);
  });

  test('pressing Sign out is on purpose; signing in again clears it', () async {
    final session = AuthSession(server((_) => _signedIn));
    await session.restore();
    await session.logout();
    expect(session.status, AuthStatus.signedOut);
    expect(session.signedOutOnPurpose, isTrue);

    await session.restore();
    expect(session.signedOutOnPurpose, isFalse);
  });

  test('sign-in reads the user, or asks which workspace', () async {
    final fake = FakeApi()
      ..post(
        '/auth/login',
        inTurn([
          workspaceChoiceJson(),
          loginJson(user: userJson(permissions: Roles.stockRoom)),
        ]),
      );
    final session = AuthSession(fake.client);

    await expectLater(
      session.login('asha@shop.in', 'secret'),
      throwsA(
        isA<WorkspaceChoiceRequired>().having((e) => e.clientIds, 'clientIds', [
          'shop-1',
          'shop-2',
        ]),
      ),
    );
    await session.login(' asha@shop.in ', 'secret', clientId: 'shop-2');

    expect(fake.sent('POST', '/auth/login').last.body, {
      'email': 'asha@shop.in',
      'password': 'secret',
      'clientId': 'shop-2',
    });
    expect(session.status, AuthStatus.signedIn);
    expect(session.can('stock_count:complete'), isTrue);
    expect(session.can('cost:view'), isFalse);
  });
}
