import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/network/api_client.dart';

import 'fake_api.dart';

Future<ApiException> failureOf(Future<Object?> call) async {
  try {
    await call;
  } on ApiException catch (e) {
    return e;
  }
  fail('expected an ApiException');
}

void main() {
  test(
    'routes by method, path pattern and query; records each request',
    () async {
      final api = FakeApi()
        ..get('/products', ok(['all']))
        ..get('/products', ok(['women']), query: {'category': 'WOMEN'})
        ..get(
          '/products/:id',
          (FakeRequest r) => ok({'id': r.path.split('/').last}),
        )
        ..post('/products', ok({'id': 'new'}));
      api.client.locationId = 'L1';

      expect(dataOf(await api.client.get('/products')), ['all']);
      expect(
        dataOf(
          await api.client.get(
            '/products',
            query: {'category': 'WOMEN', 'page': 2},
          ),
        ),
        ['women'],
      );
      expect(dataOf(await api.client.get('/products/p9')), {'id': 'p9'});
      await api.client.post('/products', body: {'title': 'Saree'});

      expect(api.log, [
        'GET /products',
        'GET /products?category=WOMEN&page=2',
        'GET /products/p9',
        'POST /products',
      ]);
      final created = api.sent('POST', '/products').single;
      expect(created.body, {'title': 'Saree'});
      expect(created.locationId, 'L1');
      expect(api.requests[1].query, {'category': 'WOMEN', 'page': '2'});
      expect(api.unanswered, isEmpty);
    },
  );

  test('an unset route answers 404 and is listed', () async {
    final api = FakeApi();
    final e = await failureOf(api.client.get('/nowhere'));
    expect(e.statusCode, 404);
    expect(e.message, 'FakeApi has no answer for GET /nowhere');
    expect(api.unanswered.single.path, '/nowhere');
  });

  test('each failure arrives as the app sees it', () async {
    final api = FakeApi();
    Future<ApiException> answer(FakeAnswer a) {
      api.get('/x', a);
      return failureOf(api.client.get('/x'));
    }

    var unauthorizedCalls = 0;
    api.client.onUnauthorized = () => unauthorizedCalls++;
    final e401 = await answer(unauthorized());
    expect((e401.statusCode, e401.isUnauthorized), (401, true));
    expect(unauthorizedCalls, 1);

    final e403 = await answer(forbidden('inventory:receive'));
    expect(e403.isForbidden, isTrue);
    expect(e403.body!['requiredPermission'], 'inventory:receive');

    expect(
      (await answer(notFound('Product not found'))).message,
      'Product not found',
    );

    final e409 = await answer(
      conflict(
        'Only 1 left of SAR-RED-M.',
        code: 'OUT_OF_STOCK',
        details: {'variantId': 'v1', 'available': 1},
      ),
    );
    expect(e409.statusCode, 409);
    expect(e409.details, {
      'code': 'OUT_OF_STOCK',
      'variantId': 'v1',
      'available': 1,
    });

    final taken = await answer(
      conflict(
        'Priya (CUS-1) is already saved with that number.',
        fields: {'existingCustomerId': 'c1'},
      ),
    );
    expect(taken.body!['existingCustomerId'], 'c1');
    expect(taken.details, isNull);

    final e400 = await answer(
      validationFailed(
        ['Phone must be 10 digits', 'Name is required'],
        paths: ['phone', 'name'],
      ),
    );
    expect(
      (e400.statusCode, e400.message),
      (400, 'Phone must be 10 digits; Name is required'),
    );

    final e429 = await answer(tooManyRequests(retryAfter: 7));
    expect(e429.statusCode, 429);

    final e500 = await answer(serverError());
    expect((e500.statusCode, e500.message), (500, 'Something went wrong'));

    expect(
      (await answer(timeout())).message,
      'The server took too long to respond. Check your connection and try again.',
    );
    expect(
      (await answer(offline())).message,
      'Could not reach the server. Check your connection and try again.',
    );
    expect(
      (await answer(malformedJson())).message,
      'Something went wrong at our end. Please try again.',
    );
  });

  test('429 carries Retry-After', () async {
    final api = FakeApi()..get('/x', tooManyRequests(retryAfter: 7));
    final e = await api.dio
        .get<Object?>('/x')
        .then<DioException?>(
          (_) => null,
          onError: (Object e) => e as DioException,
        );
    expect(e!.response!.headers.value('retry-after'), '7');
  });

  test('a held answer lands when the test says, after a newer one', () async {
    final slow = Completer<Object?>();
    final api = FakeApi()..get('/x', inTurn([slow.future, ok('second')]));

    final first = api.client.get('/x');
    expect(dataOf(await api.client.get('/x')), 'second');
    slow.complete(ok('first'));
    expect(dataOf(await first), 'first');
  });

  test('install makes it ApiClient.instance for this test', () {
    final api = FakeApi();
    expect(api.install(), same(ApiClient.instance));
  });
}
