import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/shop/shop_context.dart';

import 'fake_api.dart';
import 'fixtures.dart';
import 'pump.dart';
import 'roles.dart';

void main() {
  test(
    'role sets: money only for Manager and Buyer, the team only for Manager',
    () {
      bool sees(Set<String> role, String key) => userWith(role).can(key);
      for (final MapEntry(:key, :value) in Roles.all.entries) {
        final money = key == 'Owner' || key == 'Manager' || key == 'Buyer';
        expect(sees(value, 'cost:view'), money, reason: key);
        expect(
          sees(value, 'admin:users'),
          key == 'Owner' || key == 'Manager',
          reason: key,
        );
        expect(sees(value, 'dashboard:view'), isTrue, reason: key);
      }
      expect(sees(Roles.stockRoom, 'stock_count:view'), isTrue); // implied
      expect(sees(Roles.shopFloor, 'customer:view'), isTrue); // implied
      expect(sees(Roles.manager, 'shelf:putaway'), isFalse);
    },
  );

  test('a 401 on the session\'s client signs it out, not on purpose', () async {
    final api = FakeApi()..get('/products', unauthorized());
    final session = TestSession.as(Roles.manager, api: api.client);
    await expectLater(api.client.get('/products'), throwsA(anything));
    expect(session.status, AuthStatus.signedOut);
    expect(session.signedOutOnPurpose, isFalse);
  });

  test('the test shop picks MAIN-STORE and sends it, and switches', () async {
    final api = FakeApi()..get('/x', ok(null));
    final shop = TestShop(api: api.client);
    expect(shop.selectedLocation?.code, 'MAIN-STORE');
    expect(shop.locations.map((l) => l.type), ['STORE', 'STORE', 'ONLINE']);

    shop.selectLocation(shop.locations[1]);
    await api.client.get('/x');
    expect(api.requests.single.locationId, 'loc-branch');
    expect(shop.revision, 1);
  });

  testLooks('pumpScreen draws in every look', (tester, look) async {
    await pumpScreen(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Text(
            '${Theme.of(context).brightness.name} '
            '${ShopScope.of(context).selectedLocation?.name} '
            '${SessionScope.of(context).can('*')}',
          ),
        ),
      ),
      theme: look.theme,
      textScale: look.textScale,
    );
    expect(find.text('${look.theme.name} Main Store true'), findsOneWidget);
    expect(
      MediaQuery.of(tester.element(find.byType(Scaffold))).textScaler.scale(10),
      closeTo(10 * look.textScale, 0.001),
    );
    expectClean(tester);
  });

  testWidgets('pumpApp opens the real app where asked, on the fake API', (
    tester,
  ) async {
    final api = FakeApi(fallback: offline())
      ..get('/customers', ok([customerJson('c1')]));
    await pumpApp(
      tester,
      api: api,
      session: TestSession.as(Roles.shopFloor, api: api.client),
      at: '/customers',
    );
    expect(find.text('Priya Sharma'), findsWidgets);
    expect(api.sent('GET', '/customers').single.locationId, 'loc-main');
    expectClean(tester);
  });
}
