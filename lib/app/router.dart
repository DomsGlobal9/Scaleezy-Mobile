import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/shop/shop_context.dart';
import 'package:scaleezy/core/shop/shop_models.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/core/view_model/view_model.dart';
import 'package:scaleezy/core/widgets/async_state.dart';
import 'package:scaleezy/core/widgets/no_access_screen.dart';
import 'package:scaleezy/core/widgets/ui.dart';
import 'package:scaleezy/features/auth/presentation/login_screen.dart';
import 'package:scaleezy/features/customers/data/customer_models.dart';
import 'package:scaleezy/features/customers/presentation/customers_screen.dart';
import 'package:scaleezy/features/dashboard/presentation/home_screen.dart';
import 'package:scaleezy/features/day_book/presentation/day_book_screen.dart';
import 'package:scaleezy/features/orders/presentation/order_detail_screen.dart';
import 'package:scaleezy/features/orders/presentation/orders_screen.dart';
import 'package:scaleezy/features/orders/presentation/receipt_screen.dart';
import 'package:scaleezy/features/picking/presentation/picking_screen.dart';
import 'package:scaleezy/features/products/data/product_models.dart';
import 'package:scaleezy/features/products/data/product_repository.dart';
import 'package:scaleezy/features/products/presentation/product_detail_screen.dart';
import 'package:scaleezy/features/products/presentation/products_screen.dart';
import 'package:scaleezy/features/purchase_orders/data/purchase_order_models.dart';
import 'package:scaleezy/features/purchase_orders/data/purchase_order_repository.dart';
import 'package:scaleezy/features/purchase_orders/presentation/purchase_orders_screen.dart';
import 'package:scaleezy/features/scanner/presentation/scanner_screen.dart';
import 'package:scaleezy/features/settings/presentation/settings_screen.dart';
import 'package:scaleezy/features/shelves/data/shelf_models.dart';
import 'package:scaleezy/features/shelves/data/shelf_repository.dart';
import 'package:scaleezy/features/shelves/presentation/shelves_screen.dart';
import 'package:scaleezy/features/shell/presentation/main_navigation_screen.dart';
import 'package:scaleezy/features/shell/presentation/more_screen.dart';
import 'package:scaleezy/features/stock_counts/presentation/stock_counts_screen.dart';
import 'package:scaleezy/features/suppliers/presentation/suppliers_screen.dart';
import 'package:scaleezy/features/team/presentation/team_screen.dart';
import 'package:scaleezy/features/transfers/presentation/transfer_screen.dart';

/// Every address in the app. They copy the website's (inventory_frontend/src/App.jsx) wherever
/// both have the screen; docs/routing.md has the table.
abstract final class Paths {
  static const splash = '/splash';
  static const login = '/login';
  static const dashboard = '/dashboard';
  static const products = '/products';
  static String product(String id) => '$products/$id';
  static const scan = '/scan';
  static const orders = '/orders';
  static String order(String id) => '$orders/$id';
  static String receipt(String orderId) => '$orders/$orderId/receipt';
  static const more = '/more';
  static const shelves = '/shelves';
  static const pickOrders = '/shelves/pick';
  static const pickWalk = '/shelves/pick/walk';
  static const findPiece = '/shelves/find';
  static String spot(String spotId) => '/shelves/spots/$spotId';
  static const putAway = '/shelves/put-away';
  static const stockCounts = '/inventory/audits';
  static String stockCount(String id) => '$stockCounts/$id';
  static const purchaseOrders = '/inventory/purchase-orders';
  static String purchaseOrder(String id) => '$purchaseOrders/$id';
  static String receiveDelivery(String poId) => '$purchaseOrders/$poId/receive';
  static const suppliers = '/inventory/suppliers';
  static const transfers = '/inventory/transfers';
  static const customers = '/customers';
  static String customer(String id) => '$customers/$id';
  static const dayBook = '/reports/daybook';
  static const settings = '/settings';
  static const team = '/settings/team';
}

/// Where someone goes after signing in, or from a page they cannot open: the first of these
/// their role allows, as the web's `firstLandingPath` (its /inventory and /returns are not in
/// the app). Settings is open to everyone.
String firstLandingPath(AuthSession session) =>
    const [
      (Paths.dashboard, 'dashboard:view'),
      (Paths.products, 'product:view'),
      (Paths.orders, 'sales_order:view'),
      (Paths.purchaseOrders, 'purchase_order:view'),
      (Paths.customers, 'customer:view'),
    ].where((l) => session.can(l.$2)).map((l) => l.$1).firstOrNull ??
    Paths.settings;

/// Sign-in decides where everyone may be: splash while the saved session is checked, sign-in
/// when signed out (remembering where they were), and back there once signed in.
String? authRedirect(AuthSession session, Uri uri) {
  final path = uri.path;
  final atGate = path == Paths.splash || path == Paths.login;
  final from = atGate ? uri.queryParameters['from'] : uri.toString();
  final goBack =
      from != null &&
      from != '/' &&
      !from.startsWith(Paths.login) &&
      !from.startsWith(Paths.splash);
  String gate(String p) =>
      Uri(path: p, queryParameters: goBack ? {'from': from} : null).toString();

  return switch (session.status) {
    AuthStatus.unknown => path == Paths.splash ? null : gate(Paths.splash),
    AuthStatus.signedOut => path == Paths.login ? null : gate(Paths.login),
    AuthStatus.signedIn =>
      atGate
          ? (goBack ? from : firstLandingPath(session))
          : path == '/'
          ? firstLandingPath(session)
          : null,
  };
}

/// The app's routes. [session] drives the redirects; a 401 anywhere signs out and lands on
/// sign-in with every pushed screen gone.
GoRouter buildRouter(AuthSession session) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: session,
    redirect: (_, state) => authRedirect(session, state.uri),
    // An address the app does not have, as the web's catch-all.
    onException: (_, _, router) => router.go(Paths.dashboard),
    routes: [
      GoRoute(path: '/', redirect: (_, _) => Paths.dashboard),
      GoRoute(
        path: Paths.splash,
        pageBuilder: (_, state) => _fade(
          state,
          const Scaffold(
            backgroundColor: AppColors.bgLight,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.accentGold),
            ),
          ),
        ),
      ),
      GoRoute(
        path: Paths.login,
        pageBuilder: (_, state) => _fade(state, const LoginScreen()),
      ),

      // Full-screen tasks and screens reached from more than one tab, over the bottom bar.
      // Listed before the tabs so these addresses are matched here first.
      GoRoute(
        path: Paths.pickWalk,
        builder: (_, state) => _guard(
          'shelf:putaway',
          'picking orders',
          PickWalkScreen(
            locationId: state.uri.queryParameters['location'] ?? '',
            orderIds: (state.uri.queryParameters['orders'] ?? '')
                .split(',')
                .where((id) => id.isNotEmpty)
                .toList(),
          ),
        ),
      ),
      GoRoute(
        path: Paths.findPiece,
        builder: (_, state) => _guard(
          'shelf:view',
          'shelves',
          FindPieceScreen(
            locationId: state.uri.queryParameters['location'],
            initialQuery: state.uri.queryParameters['q'],
          ),
        ),
      ),
      GoRoute(
        path: '${Paths.shelves}/spots/:spotId',
        builder: (_, state) => _guard(
          'shelf:view',
          'shelves',
          SpotScreen(spotId: state.pathParameters['spotId']!),
        ),
      ),
      GoRoute(
        path: Paths.putAway,
        builder: (_, state) =>
            _guard('shelf:putaway', 'putting away', _putAway(state)),
      ),
      GoRoute(
        path: '${Paths.orders}/:id/receipt',
        builder: (_, state) => _guard(
          'sales_order:view',
          'orders',
          ReceiptScreen(orderId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '${Paths.purchaseOrders}/:id/receive',
        builder: (_, state) {
          final id = state.pathParameters['id']!;
          return _guard(
            'purchase_order:receive',
            'receiving deliveries',
            _Fetched<PurchaseOrderDetail>(
              title: 'Receive Now',
              value: state.extra as PurchaseOrderDetail?,
              fetch: () => PurchaseOrderRepository().purchaseOrder(id),
              builder: (po) => ReceiveDeliveryScreen(po: po),
            ),
          );
        },
      ),
      GoRoute(
        path: Paths.transfers,
        builder: (_, _) => _guard(
          'inventory:transfer',
          'moving stock',
          const TransferScreen(),
        ),
      ),

      // The bottom tabs, each keeping its own back stack.
      StatefulShellRoute.indexedStack(
        pageBuilder: (_, state, shell) =>
            _fade(state, MainNavigationScreen(navigationShell: shell)),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Paths.dashboard,
                builder: (context, _) => _guard(
                  'dashboard:view',
                  'the dashboard',
                  HomeScreen(
                    onNavigateTab: (tab) =>
                        MainNavigationScreen.selectTab(context, tab),
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Paths.products,
                builder: (_, _) =>
                    _guard('product:view', 'products', const ProductsScreen()),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, state) {
                      final id = state.pathParameters['id']!;
                      return _guard(
                        'product:view',
                        'products',
                        _Fetched<ProductItem>(
                          title: 'Product',
                          value: state.extra as ProductItem?,
                          fetch: () => ProductRepository().getProduct(id),
                          builder: (p) => ProductDetailScreen(product: p),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Paths.scan,
                // The camera runs only while this tab shows: go_router turns tickers off in
                // hidden tabs, and so does a screen pushed over the tabs.
                builder: (context, _) =>
                    ScannerScreen(active: TickerMode.of(context)),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Paths.orders,
                builder: (_, _) =>
                    _guard('sales_order:view', 'orders', const OrdersScreen()),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, state) => _guard(
                      'sales_order:view',
                      'orders',
                      OrderDetailScreen(orderId: state.pathParameters['id']!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: Paths.more, builder: (_, _) => const MoreScreen()),
              GoRoute(
                path: Paths.shelves,
                builder: (_, _) =>
                    _guard('shelf:view', 'shelves', const ShelvesScreen()),
                routes: [
                  GoRoute(
                    path: 'pick',
                    builder: (_, state) => _guard(
                      'shelf:putaway',
                      'picking orders',
                      PickOrdersScreen(location: state.extra as StockLocation?),
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: Paths.stockCounts,
                builder: (_, _) => _guard(
                  'stock_count:view',
                  'stock counts',
                  const StockCountsScreen(),
                ),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, state) => _guard(
                      'stock_count:view',
                      'stock counts',
                      StockCountScreen(countId: state.pathParameters['id']!),
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: Paths.purchaseOrders,
                builder: (_, state) => _guard(
                  'purchase_order:view',
                  'purchase orders',
                  PurchaseOrdersScreen(
                    filter: state.uri.queryParameters['filter'],
                  ),
                ),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, state) => _guard(
                      'purchase_order:view',
                      'purchase orders',
                      PurchaseOrderScreen(poId: state.pathParameters['id']!),
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: Paths.suppliers,
                builder: (_, _) => _guard(
                  'supplier:view',
                  'suppliers',
                  const SuppliersScreen(),
                ),
              ),
              GoRoute(
                path: Paths.customers,
                builder: (_, _) => _guard(
                  'customer:view',
                  'customers',
                  const CustomersScreen(),
                ),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, state) => _guard(
                      'customer:view',
                      'customers',
                      CustomerDetailScreen(
                        customerId: state.pathParameters['id']!,
                        preview: state.extra as Customer?,
                      ),
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: Paths.dayBook,
                builder: (_, _) => _guard(
                  'report:financial',
                  'the day book',
                  const DayBookScreen(),
                ),
              ),
              GoRoute(
                path: Paths.settings,
                builder: (_, _) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'team',
                    builder: (_, _) => _guard(
                      'admin:users',
                      'team and users',
                      const TeamScreen(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// Sign-in, splash and the tabs fade into each other, as they always have.
Page<void> _fade(GoRouterState state, Widget child) => CustomTransitionPage(
  key: state.pageKey,
  transitionDuration: const Duration(milliseconds: 400),
  transitionsBuilder: (_, animation, _, child) => FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
    child: child,
  ),
  child: child,
);

/// [screen] when the role holds [permission]; otherwise NoAccess in its place, keeping the
/// address, as the web's `<Guard>`.
Widget _guard(String permission, String what, Widget screen) => Builder(
  builder: (context) {
    final session = SessionScope.of(context);
    if (session.can(permission)) return screen;
    return NoAccessScreen(
      what: what,
      onLeave: () => context.go(firstLandingPath(session)),
    );
  },
);

/// Put away at `?location=`, onto `?spot=` when given (passed in, else fetched).
Widget _putAway(GoRouterState state) {
  final locationId = state.uri.queryParameters['location'] ?? '';
  final spotId = state.uri.queryParameters['spot'];
  return Builder(
    builder: (context) {
      // The spot names its store; otherwise the shop's list does.
      final storeName = ShopScope.of(
        context,
      ).locations.where((l) => l.id == locationId).firstOrNull?.name;
      Widget screen(SpotContents? target) => WaitingToShelveScreen(
        locationId: locationId,
        locationName: target?.locationName ?? storeName ?? '',
        target: target,
      );
      if (spotId == null) return screen(null);
      return _Fetched<SpotContents>(
        title: 'Put away',
        value: state.extra as SpotContents?,
        fetch: () => ShelfRepository().spot(spotId),
        builder: screen,
      );
    },
  );
}

/// Builds a screen from the object its caller passed, else fetches it first (an address
/// opened directly, e.g. coming back after signing in again).
class _Fetched<T extends Object> extends StatefulWidget {
  const _Fetched({
    super.key,
    required this.title,
    required this.value,
    required this.fetch,
    required this.builder,
  });

  final String title;
  final T? value;
  final Future<T> Function() fetch;
  final Widget Function(T value) builder;

  @override
  State<_Fetched<T>> createState() => _FetchedState<T>();
}

class _FetchedState<T extends Object> extends State<_Fetched<T>> {
  late final _vm = _FetchViewModel<T>(widget.value, widget.fetch);

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final value = _vm.value;
        if (value != null) return widget.builder(value);
        final error = _vm.error;
        return Scaffold(
          backgroundColor: AppColors.bgLight,
          body: SafeArea(
            child: Column(
              children: [
                PageHeader(title: widget.title),
                Expanded(
                  child: error != null
                      ? ErrorView(message: error, onRetry: _vm.load)
                      : const LoadingView(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FetchViewModel<T extends Object> extends ViewModel {
  _FetchViewModel(this._value, this._fetch) {
    if (_value == null) load();
  }

  final Future<T> Function() _fetch;
  T? _value;
  String? _error;

  T? get value => _value;
  String? get error => _error;

  Future<void> load() async {
    _error = null;
    notifyListeners();
    try {
      _value = await _fetch();
    } on ApiException catch (e) {
      _error = e.message;
    }
    notifyListeners();
  }
}
