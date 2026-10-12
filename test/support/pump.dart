import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:scaleezy/app/app.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/shop/shop_context.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/core/theme/theme_mode_store.dart';

import 'fake_api.dart';
import 'roles.dart';

/// The Definition of done's "Look": light and dark, at 1.0× and 1.3× text.
typedef Look = ({ThemeMode theme, double textScale});

const looks = <Look>[
  (theme: ThemeMode.light, textScale: 1.0),
  (theme: ThemeMode.dark, textScale: 1.0),
  (theme: ThemeMode.light, textScale: 1.3),
  (theme: ThemeMode.dark, textScale: 1.3),
];

/// One `testWidgets` per [looks] entry, named `description (dark, 1.3x)`.
void testLooks(
  String description,
  Future<void> Function(WidgetTester tester, Look look) body,
) {
  for (final look in looks) {
    testWidgets(
      '$description (${look.theme.name}, ${look.textScale}x)',
      (tester) => body(tester, look),
    );
  }
}

/// A phone of [width] x [height] dp at [textScale], reset when the test ends.
void setPhone(
  WidgetTester tester, {
  double width = 360,
  double height = 800,
  double textScale = 1.0,
}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Pumps [screen] as the app would hold it: inside [session] (an owner by default), [shop]
/// (MAIN-STORE selected by default), ThemeModeScope and a router, on a 360 dp phone.
///
/// The screen is the router's `/`; [routes] are added beside it. Any other path the screen
/// pushes (through `AppRoutes`) opens a page reading `Opened <path>`, so a test can check where
/// a tap went: `expect(find.text('Opened /products/p1'), findsOneWidget)`.
///
/// [settle] false pumps a single frame, for screens that animate for ever (the scanner).
/// Overflow and build errors fail the test unless taken; [expectClean] checks on the spot.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  AuthSession? session,
  ShopContext? shop,
  ThemeMode theme = ThemeMode.light,
  double width = 360,
  double height = 800,
  double textScale = 1.0,
  List<RouteBase> routes = const [],
  bool settle = true,
}) async {
  setPhone(tester, width: width, height: height, textScale: textScale);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => screen),
      ...routes,
    ],
    errorBuilder: (_, state) => Scaffold(body: Text('Opened ${state.uri}')),
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    SessionScope(
      session: session ?? TestSession.as(Roles.owner),
      child: ShopScope(
        shop: shop ?? TestShop(),
        child: ThemeModeScope(
          store: ThemeModeStore()..value = theme,
          child: MaterialApp.router(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: theme,
            routerConfig: router,
          ),
        ),
      ),
    ),
  );
  settle ? await tester.pumpAndSettle() : await tester.pump();
}

/// The whole app with its real router, signed in as [session], on [api] (installed as
/// `ApiClient.instance`, so every screen's own repositories reach it), opened at [at].
Future<void> pumpApp(
  WidgetTester tester, {
  required FakeApi api,
  AuthSession? session,
  ShopContext? shop,
  ThemeMode theme = ThemeMode.light,
  double width = 360,
  double height = 800,
  double textScale = 1.0,
  String? at,
}) async {
  api.install();
  setPhone(tester, width: width, height: height, textScale: textScale);
  await tester.pumpWidget(
    ScaleezyApp(
      session: session ?? TestSession.as(Roles.owner, api: api.client),
      shop: shop ?? TestShop(api: api.client),
      themeMode: ThemeModeStore()..value = theme,
    ),
  );
  await tester.pumpAndSettle();
  if (at != null) {
    GoRouter.of(tester.element(find.byType(Navigator).first)).go(at);
    await tester.pumpAndSettle();
  }
}

/// No overflow and no exception so far.
void expectClean(WidgetTester tester) => expect(tester.takeException(), isNull);
