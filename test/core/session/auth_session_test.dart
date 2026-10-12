import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/session/auth_session.dart';

/// /auth/session answers with [session]'s result; everything else succeeds.
ApiClient server(Object Function(RequestOptions o) session) =>
    ApiClient.withDio(
      Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (o, h) {
              if (o.path != '/auth/session') {
                return h.resolve(
                  Response(requestOptions: o, statusCode: 200, data: {}),
                );
              }
              final answer = session(o);
              answer is DioException
                  ? h.reject(answer)
                  : h.resolve(
                      Response(
                        requestOptions: o,
                        statusCode: 200,
                        data: answer,
                      ),
                    );
            },
          ),
        ),
    );

const _signedIn = {
  'authenticated': true,
  'user': {'id': 'u1', 'name': 'Asha', 'email': 'a@b.in'},
  'client': {'id': 'shop-1'},
};

void main() {
  test('an unreachable server at start keeps the saved session', () async {
    var online = false;
    final session = AuthSession(
      server(
        (o) => online
            ? _signedIn
            : DioException(
                requestOptions: o,
                type: DioExceptionType.connectionError,
              ),
      ),
    );

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
    final session = AuthSession(
      server(
        (o) => DioException(
          requestOptions: o,
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: o,
            statusCode: 401,
            data: {'message': 'Not signed in.'},
          ),
        ),
      ),
    );
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
}
