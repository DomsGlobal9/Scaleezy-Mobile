import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/network/api_client.dart';

/// A client whose every call fails as [fail] says.
ApiClient failing(DioException Function(RequestOptions o) fail) =>
    ApiClient.withDio(
      Dio()
        ..interceptors.add(
          InterceptorsWrapper(onRequest: (o, h) => h.reject(fail(o))),
        ),
    );

DioException answered(RequestOptions o, int status, Object body) =>
    DioException(
      requestOptions: o,
      type: DioExceptionType.badResponse,
      response: Response(requestOptions: o, statusCode: status, data: body),
    );

Future<ApiException> errorOf(ApiClient api) async {
  try {
    await api.get('/x');
  } on ApiException catch (e) {
    return e;
  }
  fail('expected an ApiException');
}

void main() {
  test(
    'a validation answer lists what is wrong, as the website does',
    () async {
      final e = await errorOf(
        failing(
          (o) => answered(o, 400, {
            'message': 'Validation failed',
            'errors': [
              {'path': 'phone', 'message': 'Phone must be 10 digits'},
              {'path': 'name', 'message': 'Name is required'},
            ],
          }),
        ),
      );
      expect(e.message, 'Phone must be 10 digits; Name is required');
      expect(e.statusCode, 400);
    },
  );

  test('an empty errors list falls back to the message', () async {
    final e = await errorOf(
      failing(
        (o) => answered(o, 409, {'message': 'Already taken.', 'errors': []}),
      ),
    );
    expect(e.message, 'Already taken.');
  });

  test('connection failures read as the website words them', () async {
    final slow = await errorOf(
      failing(
        (o) => DioException(
          requestOptions: o,
          type: DioExceptionType.receiveTimeout,
        ),
      ),
    );
    expect(
      slow.message,
      'The server took too long to respond. Check your connection and try again.',
    );

    final offline = await errorOf(
      failing(
        (o) => DioException(
          requestOptions: o,
          type: DioExceptionType.connectionError,
        ),
      ),
    );
    expect(
      offline.message,
      'Could not reach the server. Check your connection and try again.',
    );

    final broken = await errorOf(
      failing((o) => answered(o, 502, '<html>Bad gateway</html>')),
    );
    expect(
      broken.message,
      'Something went wrong at our end. Please try again.',
    );
  });
}
