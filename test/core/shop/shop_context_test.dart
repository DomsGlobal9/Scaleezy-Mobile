import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/shop/shop_context.dart';

Map<String, dynamic> _store(String id, {String? code, bool active = true}) => {
  'id': id,
  'code': code ?? id,
  'name': 'Store $id',
  'type': 'STORE',
  'active': active,
};

/// Answers /locations with [stores] and /branding with nothing; records the store header of
/// every request.
class _Server {
  _Server(this.stores);

  List<Map<String, dynamic>> stores;
  final headers = <String?>[];

  late final api = ApiClient.withDio(
    Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            headers.add(o.headers['x-location-id'] as String?);
            h.resolve(
              Response(
                requestOptions: o,
                statusCode: 200,
                data: o.path == '/locations'
                    ? stores
                    : {'success': true, 'data': {}},
              ),
            );
          },
        ),
      ),
  );
}

class _Session extends AuthSession {
  _Session() : super(ApiClient.withDio(Dio()));

  AuthStatus _status = AuthStatus.unknown;
  bool onPurpose = false;

  @override
  AuthStatus get status => _status;

  @override
  bool get signedOutOnPurpose => onPurpose;

  void become(AuthStatus status) {
    _status = status;
    notifyListeners();
  }
}

/// Lets the store's file writes and a reload finish.
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('store'));
  tearDown(() => dir.deleteSync(recursive: true));

  File saved() => File('${dir.path}/store_id.txt');
  ShopContext shopOn(_Server server) =>
      ShopContext(server.api, directory: () async => dir);

  test('the saved store is on the very first request', () async {
    saved().writeAsStringSync('L2');
    final server = _Server([_store('L1', code: 'MAIN-STORE'), _store('L2')]);
    final shop = shopOn(server);

    await shop.restoreSavedStore();
    await server.api.get('/anything');
    expect(server.headers.single, 'L2');

    final revision = shop.revision;
    await shop.load();
    expect(shop.selectedLocation?.id, 'L2');
    // Same store as the requests already carried: nothing to reload.
    expect(shop.revision, revision);
  });

  test('a saved store that is gone falls back to MAIN-STORE', () async {
    saved().writeAsStringSync('OLD');
    final server = _Server([
      _store('L1'),
      _store('L2', code: 'MAIN-STORE'),
      _store('OLD', active: false),
    ]);
    final shop = shopOn(server);
    await shop.restoreSavedStore();
    final revision = shop.revision;

    await shop.load();
    expect(shop.selectedLocation?.id, 'L2');
    expect(shop.revision, revision + 1);
    expect(shop.locations.map((l) => l.id), ['L1', 'L2']);
    await server.api.get('/anything');
    expect(server.headers.last, 'L2');
    await settle();
    expect(saved().readAsStringSync(), 'L2');
  });

  test('without MAIN-STORE, the first active store', () async {
    final shop = shopOn(_Server([_store('X', active: false), _store('L7')]));
    await shop.restoreSavedStore();
    await shop.load();
    expect(shop.selectedLocation?.id, 'L7');
  });

  test('choosing a store saves it and reloads the screens', () async {
    final server = _Server([_store('L1', code: 'MAIN-STORE'), _store('L2')]);
    final shop = shopOn(server);
    await shop.load();
    final revision = shop.revision;

    shop.selectLocation(shop.locations.last);
    expect(shop.revision, revision + 1);
    shop.selectLocation(shop.locations.last);
    expect(shop.revision, revision + 1);
    await settle();
    expect(saved().readAsStringSync(), 'L2');

    // A new start picks it up again.
    final again = shopOn(server);
    await again.restoreSavedStore();
    await again.load();
    expect(again.selectedLocation?.id, 'L2');
  });

  test(
    'signing out on purpose forgets the store; an expired session keeps it',
    () async {
      final server = _Server([_store('L1', code: 'MAIN-STORE'), _store('L2')]);
      final shop = shopOn(server);
      final session = _Session();
      shop.follow(session);

      session.become(AuthStatus.signedIn);
      await settle();
      shop.selectLocation(shop.locations.last);
      await settle();

      session.become(AuthStatus.signedOut); // expired
      expect(shop.selectedLocation, isNull);
      await server.api.get('/anything');
      expect(server.headers.last, 'L2');
      expect(saved().existsSync(), isTrue);

      session.become(AuthStatus.signedIn);
      await settle();
      expect(shop.selectedLocation?.id, 'L2');

      session.onPurpose = true;
      session.become(AuthStatus.signedOut);
      await settle();
      await server.api.get('/anything');
      expect(server.headers.last, isNull);
      expect(saved().existsSync(), isFalse);
    },
  );
}
