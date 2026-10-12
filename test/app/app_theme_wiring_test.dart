import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:scaleezy/app/app.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/shop/shop_context.dart';
import 'package:scaleezy/core/theme/theme_mode_store.dart';
import 'package:scaleezy/features/auth/presentation/login_screen.dart';
import 'package:scaleezy/features/settings/presentation/settings_screen.dart';
import 'package:scaleezy/features/shell/presentation/main_navigation_screen.dart';
import 'package:scaleezy/features/shell/presentation/more_screen.dart';

import '../support/fake_api.dart';
import '../support/roles.dart';

/// Signed in as a store manager whose shop answers nothing (every call fails, screens show
/// errors).
TestSession _manager() => TestSession(
  userWith(
    const {'dashboard:view', 'product:view', 'customer:view'},
    roles: ['STORE_MANAGER'],
  ),
);

void main() {
  late Directory dir;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('theme');
    FakeApi(fallback: offline()).install();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<ThemeModeStore> pumpApp(
    WidgetTester tester,
    AuthSession session, {
    ThemeMode mode = ThemeMode.light,
  }) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = ThemeModeStore(directory: () async => dir)..value = mode;
    await tester.pumpWidget(
      ScaleezyApp(
        key: UniqueKey(),
        session: session,
        shop: ShopContext(ApiClient.instance, directory: () async => dir),
        themeMode: store,
      ),
    );
    await tester.pumpAndSettle();
    return store;
  }

  Future<void> go(WidgetTester tester, String to) async {
    GoRouter.of(tester.element(find.byType(Navigator).first)).go(to);
    await tester.pumpAndSettle();
  }

  Brightness brightnessOf(WidgetTester tester, Type screen) =>
      Theme.of(tester.element(find.byType(screen))).brightness;

  testWidgets('More → Appearance switches the whole app and saves it', (
    tester,
  ) async {
    final store = await pumpApp(tester, _manager());
    await go(tester, '/more');
    expect(brightnessOf(tester, MoreScreen), Brightness.light);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(store.value, ThemeMode.dark);
    expect(brightnessOf(tester, MoreScreen), Brightness.dark);
    expect(brightnessOf(tester, MainNavigationScreen), Brightness.dark);

    await tester.tap(find.text('System'));
    await tester.pumpAndSettle();
    expect(store.value, ThemeMode.system);
    // Saved: a fresh store reads it back (the file itself is pinned in theme_mode_store_test).
    final again = ThemeModeStore(directory: () async => dir);
    await tester.runAsync(() async {
      await store.save(ThemeMode.system); // waits for the write the tap started
      await again.load();
    });
    expect(again.value, ThemeMode.system);
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('shell, More, settings and sign-in build in ${mode.name}', (
      tester,
    ) async {
      await pumpApp(tester, _manager(), mode: mode);
      expect(find.byType(MainNavigationScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      await go(tester, '/more');
      expect(find.text('Store Manager'), findsOneWidget);
      expect(find.text('shop-1'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await go(tester, '/settings');
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('Store Manager'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await pumpApp(tester, TestSession(null), mode: mode);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(brightnessOf(tester, LoginScreen).name, mode.name);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('an unreachable server at start offers to try again', (
    tester,
  ) async {
    final session = AuthSession(ApiClient.instance);
    await tester.runAsync(session.restore);
    await pumpApp(tester, session);
    expect(find.text("Couldn't reach the server"), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
  });
}
