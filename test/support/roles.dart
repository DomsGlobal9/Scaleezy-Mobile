import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/session/auth_user.dart';
import 'package:scaleezy/core/shop/shop_context.dart';
import 'package:scaleezy/core/shop/shop_models.dart';

import 'fake_api.dart';
import 'fixtures.dart';

/// The permission sets the Definition of done tests every screen with, exactly as the server
/// hands them to the app (login and /auth/session send the expanded list).
///
/// Source: inventory_backend `src/services/role-management/templates.ts` (ROLE_TEMPLATES: the
/// keys a shop gets from the "Shop floor", "Stock room", "Buyer" and "Manager" templates),
/// expanded through every `implies` in `src/config/permissions.ts` (expandPermissions), at
/// origin/main cbed286. The owner holds `*` (SUPER_ADMIN in `rbac-seed.service.ts`).
abstract final class Roles {
  static const owner = {'*'};

  /// Runs the shop day to day, including the team. No shelves, offers or owner-only settings.
  static const manager = {
    'admin:catalog',
    'admin:locations',
    'admin:users',
    'cost:manage',
    'cost:view',
    'customer:create',
    'customer:update',
    'customer:view',
    'dashboard:view',
    'dispatch:create',
    'inventory:adjust',
    'inventory:receive',
    'inventory:transfer',
    'inventory:view',
    'product:create',
    'product:update',
    'product:view',
    'purchase_order:create',
    'purchase_order:receive',
    'purchase_order:update',
    'purchase_order:view',
    'report:financial',
    'report:view',
    'return:complete',
    'return:create',
    'return:inspect',
    'return:receive',
    'return:view',
    'sales_order:cancel',
    'sales_order:confirm',
    'sales_order:counter_sale',
    'sales_order:create',
    'sales_order:update',
    'sales_order:view',
    'stock_count:complete',
    'stock_count:create',
    'stock_count:update',
    'stock_count:view',
    'supplier:create',
    'supplier:update',
    'supplier:view',
    'tryon:generate',
  };

  /// Sells to customers. Cannot see what the shop paid or what it makes.
  static const shopFloor = {
    'customer:create',
    'customer:update',
    'customer:view',
    'dashboard:view',
    'inventory:view',
    'product:view',
    'sales_order:confirm',
    'sales_order:counter_sale',
    'sales_order:create',
    'sales_order:update',
    'sales_order:view',
  };

  /// Receives, counts and moves stock. Sees quantities, not money.
  static const stockRoom = {
    'dashboard:view',
    'dispatch:create',
    'inventory:receive',
    'inventory:transfer',
    'inventory:view',
    'product:view',
    'purchase_order:receive',
    'purchase_order:view',
    'report:view',
    'return:complete',
    'return:create',
    'return:inspect',
    'return:receive',
    'return:view',
    'sales_order:view',
    'stock_count:complete',
    'stock_count:create',
    'stock_count:update',
    'stock_count:view',
  };

  /// Orders from suppliers and decides what things cost. Sees the money.
  static const buyer = {
    'cost:manage',
    'cost:view',
    'dashboard:view',
    'inventory:adjust',
    'inventory:receive',
    'inventory:view',
    'product:create',
    'product:update',
    'product:view',
    'purchase_order:create',
    'purchase_order:receive',
    'purchase_order:update',
    'purchase_order:view',
    'report:financial',
    'report:view',
    'supplier:create',
    'supplier:update',
    'supplier:view',
  };

  /// The five, by the name the plan uses, for `for (final MapEntry(:key, :value) in ...)`.
  static const all = {
    'Owner': owner,
    'Manager': manager,
    'Shop floor': shopFloor,
    'Stock room': stockRoom,
    'Buyer': buyer,
  };
}

/// A signed-in person holding [permissions] (an owner by default).
AuthUser userWith(
  Set<String> permissions, {
  String name = 'Asha Rao',
  List<String>? roles,
}) => AuthUser(
  id: 'u1',
  clientId: 'shop-1',
  name: name,
  email: 'asha@shop.in',
  roles: roles ?? [permissions.contains('*') ? 'SUPER_ADMIN' : 'STAFF'],
  permissions: permissions,
);

/// A session the test controls, with no network: signed in as [user] (null: signed out).
/// [become] moves it like the real one, and a 401 from its client signs it out as the real one
/// does, so `TestSession(user, api: fakeApi.client)` sees an expiry mid-flow.
class TestSession extends AuthSession {
  TestSession(AuthUser? user, {ApiClient? api, AuthStatus? status})
    : this._(user, api ?? offlineClient(), status);

  TestSession._(this._user, ApiClient api, AuthStatus? status)
    : _status =
          status ??
          (_user == null ? AuthStatus.signedOut : AuthStatus.signedIn),
      super(api) {
    api.onUnauthorized = () {
      if (_status == AuthStatus.signedIn) become(AuthStatus.signedOut);
    };
  }

  /// Signed in with exactly [permissions].
  TestSession.as(Set<String> permissions, {ApiClient? api})
    : this(userWith(permissions), api: api);

  AuthUser? _user;
  AuthStatus _status;
  bool _onPurpose = false;

  /// Calls to [login], [restore] and [logout], in order (`login email` etc.).
  final calls = <String>[];

  @override
  AuthStatus get status => _status;

  @override
  AuthUser? get user => _user;

  @override
  bool get signedOutOnPurpose => _onPurpose;

  @override
  bool can(String permission) => user?.can(permission) ?? false;

  /// Moves to [status]; signing in with [permissions] replaces the user's permissions.
  void become(
    AuthStatus status, {
    Set<String>? permissions,
    bool onPurpose = false,
  }) {
    _status = status;
    _onPurpose = onPurpose;
    if (status == AuthStatus.signedIn) {
      _user = permissions == null && _user != null
          ? _user
          : userWith(permissions ?? Roles.owner);
    } else if (status == AuthStatus.signedOut) {
      _user = null;
    }
    notifyListeners();
  }

  @override
  Future<void> login(String email, String password, {String? clientId}) async {
    calls.add('login $email');
    become(AuthStatus.signedIn);
  }

  @override
  Future<void> restore() async => calls.add('restore');

  @override
  Future<void> logout() async {
    calls.add('logout');
    become(AuthStatus.signedOut, onPurpose: true);
  }
}

/// A store, as the app holds it.
StockLocation store(
  String id, {
  String type = 'STORE',
  String? code,
  String? name,
  bool active = true,
}) => StockLocation(
  id: id,
  code: code ?? id,
  name: name ?? 'Store $id',
  type: type,
  active: active,
);

/// The active stores of [locationsJson]: MAIN-STORE, a branch and the ONLINE store.
List<StockLocation> defaultStores() =>
    locationsJson().map(StockLocation.fromJson).where((l) => l.active).toList();

/// The shop around the session, with no network: [stores] (the defaults: MAIN-STORE, a branch,
/// ONLINE), [selected] by id (else MAIN-STORE, else the first, as the real one picks), and
/// [branding]. Its client carries the selected store as `x-location-id`, like the real one.
/// [selectLocation] switches and bumps [revision]; [load] only counts.
class TestShop extends ShopContext {
  TestShop({
    List<StockLocation>? stores,
    String? selected,
    Branding branding = const Branding(businessName: 'Lakshmi Silks'),
    ApiClient? api,
  }) : this._(
         api ?? offlineClient(),
         stores ?? defaultStores(),
         selected,
         branding,
       );

  TestShop._(this._api, this._stores, String? selected, this._branding)
    : super(_api) {
    _selected =
        _stores.where((l) => l.id == selected).firstOrNull ??
        _stores.where((l) => l.code == 'MAIN-STORE').firstOrNull ??
        _stores.firstOrNull;
    _api.locationId = _selected?.id;
  }

  final ApiClient _api;
  final List<StockLocation> _stores;
  final Branding _branding;
  StockLocation? _selected;
  int _revision = 0;
  int loads = 0;

  @override
  Branding get branding => _branding;

  @override
  List<StockLocation> get locations => _stores;

  @override
  StockLocation? get selectedLocation => _selected;

  @override
  int get revision => _revision;

  @override
  Future<void> load() async => loads++;

  @override
  void selectLocation(StockLocation location) {
    if (location.id == _selected?.id) return;
    _selected = location;
    _api.locationId = location.id;
    _revision++;
    notifyListeners();
  }
}
