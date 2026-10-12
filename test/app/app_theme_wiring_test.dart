import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:scaleezy/app/app.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/session/auth_user.dart';
import 'package:scaleezy/core/shop/shop_context.dart';
import 'package:scaleezy/core/theme/theme_mode_store.dart';
import 'package:scaleezy/features/auth/presentation/login_screen.dart';
import 'package:scaleezy/features/settings/presentation/settings_screen.dart';
import 'package:scaleezy/features/shell/presentation/main_navigation_screen.dart';
import 'package:scaleezy/features/shell/presentation/more_screen.dart';

/// Signed in as an owner whose shop answers nothing (every call fails, screens show errors).
class _Session extends AuthSession {
  _Session(this._status) : super(ApiClient.withDio(Dio()));

  final AuthStatus _status;

  @override
  AuthStatus get status => _status;

  @override
  AuthUser? get user => const AuthUser(
    id: 'u1',
    clientId: 'shop-1',
    name: 'Asha Rao',
    email: 'asha@shop.in',
    roles: ['STORE_MANAGER'],
    permissions: {'dashboard:view', 'product:view', 'customer:view'},
  );

  @override
  bool can(String permission) => user!.can(permission);
}

ApiClient _offline() => ApiClient.withDio(
  Dio()
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) => h.reject(
          DioException(
            requestOptions: o,
            type: DioExceptionType.connectionError,
          ),
        ),
      ),
    ),
);

void main() {
  late Directory dir;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('theme');
    ApiClient.debugInstance = _offline();
  });
  tearDown(() {
    ApiClient.debugInstance = null;
    dir.deleteSync(recursive: true);
  });

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
    final store = await pumpApp(tester, _Session(AuthStatus.signedIn));
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
      await pumpApp(tester, _Session(AuthStatus.signedIn), mode: mode);
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

      await pumpApp(tester, _Session(AuthStatus.signedOut), mode: mode);
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
