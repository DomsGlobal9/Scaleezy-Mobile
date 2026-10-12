import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/network/api_client.dart';

/// One request as the fake backend received it.
class FakeRequest {
  FakeRequest({
    required this.method,
    required this.path,
    required this.query,
    required this.headers,
    required this.body,
  });

  /// GET, POST, PUT, PATCH or DELETE.
  final String method;

  /// Relative to `/api/v1`, as in `ApiEndpoints` (e.g. `/products/p1`).
  final String path;

  /// As the server reads it: every value a string, empty values already dropped by ApiClient.
  final Map<String, String> query;
  final Map<String, dynamic> headers;

  /// The JSON body as sent (usually a Map), or null.
  final Object? body;

  /// The selected store, sent on every request once ShopContext knows it.
  String? get locationId => headers['x-location-id'] as String?;

  @override
  String toString() =>
      '$method ${Uri(path: path, queryParameters: query.isEmpty ? null : query)}';
}

/// What the fake backend answers: a status and a JSON body, or a failure that never reached
/// the server (timeout, offline).
class FakeAnswer {
  const FakeAnswer(this.status, this.body, {this.headers = const {}})
    : failure = null,
      rawBody = null;

  /// A body that is not valid JSON, sent as JSON.
  const FakeAnswer.raw(this.status, String this.rawBody)
    : body = null,
      headers = const {},
      failure = null;

  const FakeAnswer.failed(DioExceptionType this.failure)
    : status = 0,
      body = null,
      headers = const {},
      rawBody = null;

  final int status;
  final Object? body;
  final Map<String, String> headers;
  final DioExceptionType? failure;
  final String? rawBody;
}

/// Decides the answer from the request; may return anything [FakeApi.on] accepts.
typedef FakeHandler = Object? Function(FakeRequest request);

/// A fake backend for one test: routes by method + path (+ query), records every request and
/// answers with fixtures or failures. No network, no new package: it is Dio's adapter.
///
/// ```dart
/// final api = FakeApi()
///   ..get('/products', productListJson([productJson('p1')]))
///   ..post('/inventory/stock-in', forbidden('inventory:receive'));
/// final repo = ProductRepository(api.client);
/// ```
///
/// An answer is a [FakeAnswer] (see the helpers below), a [FakeHandler], a `Future` of either
/// (complete it later to land a slow answer after a newer one), or plain JSON for a 200.
/// A request nobody set up answers 404 "FakeApi has no answer for …" and is kept in
/// [unanswered].
class FakeApi implements HttpClientAdapter {
  /// [fallback] answers whatever no route matches (e.g. `offline()` for "the shop answers
  /// nothing"); without it such a request gets the 404 above.
  FakeApi({this.fallback}) {
    dio.httpClientAdapter = this;
  }

  final Object? fallback;

  static const _base = 'https://fake.scaleezy.test/api/v1';

  final dio = Dio(
    BaseOptions(
      baseUrl: _base,
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    ),
  );

  /// The app's client on this backend. Without the real one's cookie jar and 429 retries.
  late final ApiClient client = ApiClient.withDio(dio);

  /// Every request, in order.
  final requests = <FakeRequest>[];

  /// Requests no route matched.
  final unanswered = <FakeRequest>[];

  final _routes = <_Route>[];

  /// Answers [method] [path] with [answer]. `:name` segments match anything (`/products/:id`);
  /// [query] entries must match exactly, others are ignored. The last matching route wins, so
  /// a test can override a default.
  void on(
    String method,
    String path,
    Object? answer, {
    Map<String, String>? query,
  }) => _routes.add(_Route(method.toUpperCase(), path, query, answer));

  void get(String path, Object? answer, {Map<String, String>? query}) =>
      on('GET', path, answer, query: query);
  void post(String path, Object? answer, {Map<String, String>? query}) =>
      on('POST', path, answer, query: query);
  void put(String path, Object? answer, {Map<String, String>? query}) =>
      on('PUT', path, answer, query: query);
  void patch(String path, Object? answer, {Map<String, String>? query}) =>
      on('PATCH', path, answer, query: query);
  void delete(String path, Object? answer, {Map<String, String>? query}) =>
      on('DELETE', path, answer, query: query);

  /// Makes [client] the app-wide `ApiClient.instance` (for screens and the router that build
  /// their own repositories) until the test ends.
  ApiClient install() {
    ApiClient.debugInstance = client;
    addTearDown(() => ApiClient.debugInstance = null);
    return client;
  }

  /// The requests to [method] [path] (`:name` patterns allowed), in order.
  List<FakeRequest> sent(String method, String path) => requests
      .where((r) => r.method == method.toUpperCase() && _matches(path, r.path))
      .toList();

  /// `GET /x`-style lines for every request, handy in `expect`.
  List<String> get log => requests.map((r) => r.toString()).toList();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final uri = options.uri;
    final path = uri.path.startsWith('/api/v1')
        ? uri.path.substring('/api/v1'.length)
        : uri.path;
    final request = FakeRequest(
      method: options.method.toUpperCase(),
      path: path,
      query: uri.queryParameters,
      headers: Map.of(options.headers),
      body: options.data,
    );
    requests.add(request);

    final route = _routes.reversed.where((r) => r.matches(request)).firstOrNull;
    if (route == null) unanswered.add(request);
    final answer = await _resolve(
      route != null
          ? route.answer
          : fallback ?? notFound('FakeApi has no answer for $request'),
      request,
    );

    final failure = answer.failure;
    if (failure != null) {
      throw DioException(requestOptions: options, type: failure);
    }
    return ResponseBody.fromString(
      answer.rawBody ?? jsonEncode(answer.body),
      answer.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        for (final h in answer.headers.entries) h.key.toLowerCase(): [h.value],
      },
    );
  }

  static Future<FakeAnswer> _resolve(Object? answer, FakeRequest r) async {
    var a = answer;
    while (true) {
      if (a is Future) {
        a = await a;
      } else if (a is FakeHandler) {
        a = a(r);
      } else if (a is FakeAnswer) {
        return a;
      } else {
        return FakeAnswer(200, a);
      }
    }
  }

  @override
  void close({bool force = false}) {}
}

class _Route {
  _Route(this.method, this.path, this.query, this.answer);

  final String method;
  final String path;
  final Map<String, String>? query;
  final Object? answer;

  bool matches(FakeRequest r) =>
      r.method == method &&
      _matches(path, r.path) &&
      (query?.entries.every((e) => r.query[e.key] == e.value) ?? true);
}

bool _matches(String pattern, String path) {
  final want = pattern.split('/');
  final got = path.split('/');
  if (want.length != got.length) return false;
  for (var i = 0; i < want.length; i++) {
    if (!want[i].startsWith(':') && want[i] != got[i]) return false;
  }
  return true;
}

/// A client for repository fakes that override every call. Anything that slips through fails
/// as offline; it never reaches the network.
ApiClient offlineClient() =>
    ApiClient.withDio(Dio()..httpClientAdapter = _Offline());

class _Offline implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => throw DioException(
    requestOptions: options,
    type: DioExceptionType.connectionError,
  );

  @override
  void close({bool force = false}) {}
}

// ---- Answers, shaped as the backend sends them ---------------------------------------------

/// `{success: true, data}`: the usual envelope.
Map<String, Object?> ok(Object? data) => {'success': true, 'data': data};

/// Answers each call with the next of [answers], then the last one from then on.
FakeHandler inTurn(List<Object?> answers) {
  var i = 0;
  return (_) => answers[i < answers.length ? i++ : answers.length - 1];
}

/// [answer] after [delay] (in widget tests, `tester.pump(delay)` lets it land). To decide in
/// the test when it lands, answer with a `Completer`'s future instead.
Future<Object?> delayed(Duration delay, Object? answer) =>
    Future.delayed(delay, () => answer);

/// 401 from auth.middleware: the session ended. The real `AuthSession` (and `TestSession`)
/// signs out on it.
FakeAnswer unauthorized([
  String message = 'Unauthorized: Invalid or expired token',
]) => FakeAnswer(401, {'success': false, 'message': message});

/// 403 from requirePermission. The server's sentence uses the permission's label
/// ("You do not have permission to: receive goods against an order. Ask whoever manages your
/// team."); without [message] this is its fallback for a key it has no label for.
FakeAnswer forbidden(String permission, {String? message}) => FakeAnswer(403, {
  'success': false,
  'message': message ?? 'Forbidden: Missing required permission [$permission]',
  'requiredPermission': permission,
});

FakeAnswer notFound([String message = 'Not found']) =>
    FakeAnswer(404, {'success': false, 'message': message});

/// 409: a write race, an invalid move, or a rule. [code] (+ [details]) goes in `details` as
/// respondWithError sends it (e.g. `OUT_OF_STOCK` with `variantId`, `available`); [fields] go
/// at the top level as some controllers send them (the customer routes' `existingCustomerId`).
FakeAnswer conflict(
  String message, {
  String? code,
  Map<String, Object?> details = const {},
  Map<String, Object?> fields = const {},
}) => FakeAnswer(409, {
  'success': false,
  'message': message,
  ...fields,
  if (code != null || details.isNotEmpty)
    'details': {'code': ?code, ...details},
});

/// 400 from the zod error handler: one entry per field. ApiClient joins the messages.
FakeAnswer validationFailed(
  List<String> messages, {
  List<String> paths = const [],
}) => FakeAnswer(400, {
  'success': false,
  'message': 'Validation failed',
  'errors': [
    for (var i = 0; i < messages.length; i++)
      {
        'code': 'custom',
        'path': [if (i < paths.length) paths[i]],
        'message': messages[i],
      },
  ],
});

/// 429 from the rate limiter (100 a minute per IP). The fake's client has no retry, so this
/// reaches the caller as an error.
FakeAnswer tooManyRequests({
  int? retryAfter = 5,
  String message = 'Too many requests, please try again later.',
}) => FakeAnswer(
  429,
  {'success': false, 'message': message},
  headers: {'retry-after': ?retryAfter?.toString()},
);

FakeAnswer serverError([String message = 'Something went wrong']) =>
    FakeAnswer(500, {'success': false, 'message': message});

/// The server took longer than the client waits.
FakeAnswer timeout() =>
    const FakeAnswer.failed(DioExceptionType.receiveTimeout);

/// No connection at all.
FakeAnswer offline() =>
    const FakeAnswer.failed(DioExceptionType.connectionError);

/// A 200 whose body is cut off mid-JSON (a proxy or a crash mid-write).
FakeAnswer malformedJson() =>
    const FakeAnswer.raw(200, '{"success": true, "da');
