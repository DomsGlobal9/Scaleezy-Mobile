import 'dart:async';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Override at build time: flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4006/api/v1
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://inventory-backend-1-ym8d.onrender.com/api/v1',
);

/// A failed call, carrying the server's `message` unchanged -- it is written for a shop
/// assistant to read, so screens show it as it is.
class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final Map<String, dynamic>? details;

  const ApiException(this.message, {this.statusCode, this.details});

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._(this._dio);

  final Dio _dio;

  /// The store the person is standing in, sent as `x-location-id`. Null = whole shop.
  set locationId(String? id) {
    if (id == null) {
      _dio.options.headers.remove('x-location-id');
    } else {
      _dio.options.headers['x-location-id'] = id;
    }
  }

  /// Called once per expired session so the app can go back to sign-in.
  VoidCallback? onUnauthorized;

  static ApiClient? _instance;
  static ApiClient get instance {
    final client = _instance;
    if (client == null) throw StateError('ApiClient.init() has not run');
    return client;
  }

  /// For tests: no cookie jar, no retries.
  @visibleForTesting
  factory ApiClient.withDio(Dio dio) => ApiClient._(dio);

  /// For tests that build screens with their default repositories (the router tests).
  @visibleForTesting
  static set debugInstance(ApiClient? client) => _instance = client;

  static Future<ApiClient> init() async {
    if (_instance != null) return _instance!;

    final dio = Dio(
      BaseOptions(
        baseUrl: kApiBaseUrl,
        // The database is in Singapore; a single call has measured 12-56s under load.
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 90),
        sendTimeout: const Duration(seconds: 30),
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
      ),
    );

    // The session is an httpOnly `token` cookie; a persisted jar keeps it across restarts.
    // On web the browser owns cookies, so there is nothing to manage here.
    if (!kIsWeb) {
      final dir = await getApplicationSupportDirectory();
      final jar = PersistCookieJar(
        storage: FileStorage('${dir.path}/.cookies/'),
      );
      dio.interceptors.add(CookieManager(jar));
    }

    final client = ApiClient._(dio);
    dio.interceptors.add(_RetryOn429(dio));
    _instance = client;
    return client;
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get(path, queryParameters: _clean(query)));

  /// [acceptUnsuccessful] hands back a 200 `{success: false}` body instead of throwing --
  /// login uses it for the "choose a workspace" answer.
  Future<dynamic> post(
    String path, {
    Object? body,
    bool acceptUnsuccessful = false,
  }) => _send(
    () => _dio.post(path, data: body),
    acceptUnsuccessful: acceptUnsuccessful,
  );

  Future<dynamic> patch(String path, {Object? body}) =>
      _send(() => _dio.patch(path, data: body));

  Future<dynamic> put(String path, {Object? body}) =>
      _send(() => _dio.put(path, data: body));

  /// Returns the decoded body. Most routes answer `{success, data}`, a few answer the raw
  /// object -- callers unwrap with [dataOf].
  Future<dynamic> _send(
    Future<Response<dynamic>> Function() call, {
    bool acceptUnsuccessful = false,
  }) async {
    try {
      final res = await call();
      final body = res.data;
      if (!acceptUnsuccessful && body is Map && body['success'] == false) {
        throw ApiException(
          _messageOf(body) ?? 'That did not work.',
          statusCode: res.statusCode,
        );
      }
      return body;
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  ApiException _toApiException(DioException e) {
    final status = e.response?.statusCode;
    final body = e.response?.data;

    if (status == 401) onUnauthorized?.call();

    if (body is Map) {
      final details = body['details'];
      return ApiException(
        _messageOf(body) ?? _fallbackFor(status),
        statusCode: status,
        details: details is Map<String, dynamic> ? details : null,
      );
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return const ApiException(
          'The server is taking too long. Check the connection and try again.',
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          'Cannot reach the server. Check the internet connection.',
        );
      default:
        return ApiException(_fallbackFor(status), statusCode: status);
    }
  }

  static String? _messageOf(Map body) {
    final m = body['message'] ?? body['error'];
    return m is String && m.trim().isNotEmpty ? m : null;
  }

  static String _fallbackFor(int? status) {
    switch (status) {
      case 401:
        return 'Your session has ended. Sign in again.';
      case 403:
        return 'Your role does not allow this.';
      case 404:
        return 'Not found.';
      case 429:
        return 'Too many requests. Wait a moment and try again.';
      default:
        return 'Something went wrong. Try again.';
    }
  }

  static Map<String, dynamic>? _clean(Map<String, dynamic>? q) {
    if (q == null) return null;
    return Map.of(q)
      ..removeWhere((_, v) => v == null || (v is String && v.isEmpty));
  }
}

/// `{success, data: X}` -> X; anything else is returned as is.
dynamic dataOf(dynamic body) =>
    body is Map && body.containsKey('data') ? body['data'] : body;

/// 100 requests/min per IP, shared by a whole shop on one wifi. Wait and retry rather than
/// fail the screen; honour Retry-After when the server sends it.
class _RetryOn429 extends Interceptor {
  _RetryOn429(this._dio);

  final Dio _dio;
  static const _maxAttempts = 2;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final attempt = (err.requestOptions.extra['retry429'] as int?) ?? 0;
    if (err.response?.statusCode != 429 || attempt >= _maxAttempts) {
      return handler.next(err);
    }

    final retryAfter = int.tryParse(
      err.response?.headers.value('retry-after') ?? '',
    );
    // Login throttling can ask for minutes; that is not worth waiting on silently.
    if (retryAfter != null && retryAfter > 20) return handler.next(err);

    await Future.delayed(Duration(seconds: retryAfter ?? 3 * (attempt + 1)));
    final options = err.requestOptions..extra['retry429'] = attempt + 1;
    try {
      handler.resolve(await _dio.fetch(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
