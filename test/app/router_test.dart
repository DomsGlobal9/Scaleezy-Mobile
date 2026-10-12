import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:scaleezy/app/app.dart';
import 'package:scaleezy/app/app_routes.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/shop/shop_context.dart';
import 'package:scaleezy/core/widgets/no_access_screen.dart';
import 'package:scaleezy/features/auth/presentation/login_screen.dart';
import 'package:scaleezy/features/customers/presentation/customers_screen.dart';
import 'package:scaleezy/features/dashboard/presentation/home_screen.dart';
import 'package:scaleezy/features/products/presentation/product_detail_screen.dart';
import 'package:scaleezy/features/products/presentation/products_screen.dart';
import 'package:scaleezy/features/scanner/presentation/scanner_screen.dart';
import 'package:scaleezy/features/shell/presentation/more_screen.dart';

import '../features/products/products_fakes.dart' show product;
import '../support/fake_api.dart';
import '../support/fixtures.dart';
import '../support/roles.dart';

/// The server: GET /products/p1 answers; every other call fails, so screens show their error.
FakeApi _server() => FakeApi(fallback: offline())
  ..get('/products/p1', ok(productJson('p1', variantCount: 2, totalUnits: 5)));

void main() {
  late TestSession session;

  setUp(() {
    _server().install();
    session = TestSession(null, status: AuthStatus.unknown);
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ScaleezyApp(session: session, shop: ShopContext(ApiClient.instance)),
    );
    // Not pumpAndSettle: the splash spinner turns until the session is known.
    await tester.pump();
  }

  GoRouter router(WidgetTester tester) =>
      GoRouter.of(tester.element(find.byType(Navigator).first));

  // The top screen's address, pushed ones included.
  String location(WidgetTester tester) => router(tester).state.uri.toString();

  Future<void> go(WidgetTester tester, String to) async {
    router(tester).go(to);
    await tester.pumpAndSettle();
  }

  Future<void> signIn(WidgetTester tester, Set<String> perms) async {
    session.become(AuthStatus.signedIn, permissions: perms);
    await tester.pumpAndSettle();
  }

  // The bottom bar's label, after any page title with the same words.
  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  testWidgets('signed out goes to sign-in, then back where it was', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(location(tester), '/splash');

    session.become(AuthStatus.signedOut);
    await tester.pumpAndSettle();
    expect(location(tester), '/login');
    expect(find.byType(LoginScreen), findsOneWidget);

    await go(tester, '/customers');
    expect(location(tester), '/login?from=%2Fcustomers');
    expect(find.byType(LoginScreen), findsOneWidget);

    await signIn(tester, {'dashboard:view', 'customer:view'});
    expect(location(tester), '/customers');
    expect(find.byType(CustomersScreen), findsOneWidget);

    // Signing out drops every screen; signing in again returns to it.
    session.become(AuthStatus.signedOut);
    await tester.pumpAndSettle();
    expect(location(tester), '/login?from=%2Fcustomers');
    expect(find.byType(CustomersScreen), findsNothing);
  });

  testWidgets('a deliberate sign-out keeps nothing for the next person', (
    tester,
  ) async {
    await pumpApp(tester);
    await signIn(tester, {'dashboard:view', 'customer:view'});
    await go(tester, '/customers');

    session.become(AuthStatus.signedOut, onPurpose: true);
    await tester.pumpAndSettle();
    expect(location(tester), '/login');

    await signIn(tester, {'dashboard:view', 'customer:view'});
    expect(location(tester), '/dashboard');
  });

  testWidgets('a page the role cannot open names what it wanted to do', (
    tester,
  ) async {
    await pumpApp(tester);
    await signIn(tester, {'dashboard:view'});

    await go(tester, '/shelves/pick');
    expect(find.text('You cannot pick orders'), findsOneWidget);
    expect(
      find.text(
        'Ask whoever manages your team for the permission to put stock away and move it.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'sign-in with nowhere to return to opens the first allowed page',
    (tester) async {
      await pumpApp(tester);
      session.become(AuthStatus.signedOut);
      await tester.pumpAndSettle();

      await signIn(tester, {'product:view'});
      expect(location(tester), '/products');
      expect(find.byType(ProductsScreen), findsOneWidget);
    },
  );

  testWidgets('an unknown address goes to the dashboard', (tester) async {
    await pumpApp(tester);
    await signIn(tester, {'dashboard:view'});

    await go(tester, '/no/such/page');
    expect(location(tester), '/dashboard');
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('without the permission, NoAccess in place with a way out', (
    tester,
  ) async {
    await pumpApp(tester);
    await signIn(tester, {'product:view'});

    await go(tester, '/inventory/suppliers');
    expect(location(tester), '/inventory/suppliers');
    expect(find.byType(NoAccessScreen), findsOneWidget);
    expect(find.text('Not part of your role'), findsOneWidget);
    expect(
      find.text(
        'Ask whoever manages your team for the permission to see suppliers.',
      ),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsNothing);

    await tester.tap(find.text('Go to a page you can open'));
    await tester.pumpAndSettle();
    expect(location(tester), '/products');
  });

  testWidgets('each tab keeps its stack; back on a tab goes to Dashboard', (
    tester,
  ) async {
    await pumpApp(tester);
    await signIn(tester, {'dashboard:view', 'product:view', 'customer:view'});
    expect(location(tester), '/dashboard');

    await tapTab(tester, 'More');
    await tester.tap(find.text('Customers'));
    await tester.pumpAndSettle();
    expect(location(tester), '/customers');

    await tapTab(tester, 'Products');
    expect(find.byType(ProductsScreen), findsOneWidget);
    await tapTab(tester, 'More');
    expect(location(tester), '/customers');
    expect(find.byType(CustomersScreen), findsOneWidget);

    // Tapping the tab showing returns it to its first screen.
    await tapTab(tester, 'More');
    expect(location(tester), '/more');
    await tester.tap(find.text('Customers'));
    await tester.pumpAndSettle();

    await back(tester);
    expect(location(tester), '/more');
    expect(find.byType(MoreScreen), findsOneWidget);
    await back(tester);
    expect(location(tester), '/dashboard');
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('the camera runs only while the Scan tab shows', (tester) async {
    await pumpApp(tester);
    await signIn(tester, {'dashboard:view'});

    ScannerScreen scanner() => tester.widget<ScannerScreen>(
      find.byType(ScannerScreen, skipOffstage: false),
    );
    await tester.tap(find.text('Scan'));
    // Not pumpAndSettle: the laser line animates for as long as the tab shows.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(location(tester), '/scan');
    expect(scanner().active, isTrue);

    await tapTab(tester, 'Dashboard');
    expect(scanner().active, isFalse);
  });

  testWidgets('a pushed screen hands its result back to the caller', (
    tester,
  ) async {
    await pumpApp(tester);
    await signIn(tester, {'product:view'});

    final changed = AppRoutes.productDetail(
      tester.element(find.byType(ProductsScreen)),
      product('p9', title: 'Silk Kurta'),
    );
    await tester.pumpAndSettle();
    expect(location(tester), '/products/p9');
    expect(find.text('Silk Kurta'), findsWidgets);

    Navigator.of(tester.element(find.byType(ProductDetailScreen))).pop(true);
    await tester.pumpAndSettle();
    expect(await changed, isTrue);
    expect(location(tester), '/products');
  });

  testWidgets('a product opened by address is fetched by id', (tester) async {
    await pumpApp(tester);
    await signIn(tester, {'product:view'});

    await go(tester, '/products/p1');
    expect(find.byType(ProductDetailScreen), findsOneWidget);
    expect(find.text('Banarasi Saree'), findsWidgets);

    // The list sits underneath.
    await back(tester);
    expect(location(tester), '/products');
  });

  testWidgets('a low-stock row on the dashboard opens its product by id', (
    tester,
  ) async {
    await pumpApp(tester);
    await signIn(tester, {'dashboard:view', 'product:view'});
    expect(location(tester), '/dashboard');

    final changed = AppRoutes.productById(
      tester.element(find.byType(HomeScreen)),
      'p1',
    );
    await tester.pumpAndSettle();
    expect(location(tester), '/products/p1');
    expect(find.byType(ProductDetailScreen), findsOneWidget);
    expect(find.text('Banarasi Saree'), findsWidgets);

    await back(tester);
    expect(await changed, isNull);
    expect(location(tester), '/dashboard');
  });
}
