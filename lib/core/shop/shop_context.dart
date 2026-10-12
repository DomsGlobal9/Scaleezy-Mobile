import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/shop/shop_models.dart';
import 'package:scaleezy/core/shop/shop_repository.dart';

/// The shop around the signed-in person: its name and logo, its stores, and the one store the
/// whole app is looking at, as the website's `LocationContext`.
///
/// There is always exactly one store once [load] has the list: the saved one if it is still
/// active, else the store coded `MAIN-STORE`, else the first. The choice is saved to a small
/// file and read back by [restoreSavedStore] before the first request, so `x-location-id` is on
/// every call from the start. Changing the store bumps [revision] so screens know to reload.
class ShopContext extends ChangeNotifier {
  ShopContext(this._api, {Future<Directory> Function()? directory})
    : _repo = ShopRepository(_api),
      _directory = directory ?? getApplicationSupportDirectory;

  final ApiClient _api;
  final ShopRepository _repo;
  final Future<Directory> Function() _directory;

  Branding _branding = const Branding();
  List<StockLocation> _locations = const [];
  StockLocation? _selected;
  String? _savedId;
  int _revision = 0;

  Branding get branding => _branding;
  List<StockLocation> get locations => _locations;

  /// The store every screen works in. Non-null once [load] has the store list; null only
  /// before that, or when the role cannot list stores (then the saved id, if any, is still
  /// sent and the server falls back to MAIN-STORE without one).
  StockLocation? get selectedLocation => _selected;
  int get revision => _revision;

  Future<File> get _file async =>
      File('${(await _directory()).path}/store_id.txt');

  /// App start, before `runApp`: puts the saved store on every request from now on.
  Future<void> restoreSavedStore() async {
    try {
      final id = (await (await _file).readAsString()).trim();
      if (id.isNotEmpty) {
        _savedId = id;
        _api.locationId = id;
      }
    } catch (_) {
      // Nothing saved yet, or unreadable: the server's default store until [load].
    }
  }

  Future<void> load() async {
    // Both are extras around the app, never a reason to stop it.
    final results = await Future.wait([
      _repo.getBranding().then<Object?>((b) => b).catchError((_) => null),
      _repo.getLocations().then<Object?>((l) => l).catchError((_) => null),
    ]);
    if (results[0] is Branding) _branding = results[0] as Branding;
    if (results[1] is List<StockLocation>) {
      _locations = (results[1] as List<StockLocation>)
          .where((l) => l.active)
          .toList();
      final wanted = _selected?.id ?? _savedId;
      final pick =
          _locations.where((l) => l.id == wanted).firstOrNull ??
          _locations.where((l) => l.code == 'MAIN-STORE').firstOrNull ??
          _locations.firstOrNull;
      if (pick != null) {
        _selected = pick;
        // Only a different store than the requests so far carried is a reason to reload.
        if (pick.id != _savedId) _apply(pick.id);
      }
    }
    notifyListeners();
  }

  void selectLocation(StockLocation location) {
    if (location.id == _selected?.id) return;
    _selected = location;
    _apply(location.id);
    notifyListeners();
  }

  void _apply(String id) {
    _savedId = id;
    _api.locationId = id;
    _revision++;
    _save(id);
  }

  Future<void> _saving = Future.value();

  // Saves run one after another, so a quick second switch can't be overwritten by the first.
  Future<void> _save(String? id) => _saving = _saving.then((_) => _write(id));

  Future<void> _write(String? id) async {
    try {
      final file = await _file;
      if (id == null) {
        if (await file.exists()) await file.delete();
      } else {
        await file.writeAsString(id, flush: true);
      }
    } catch (_) {
      // Not remembered across restarts; the app still works on this store now.
    }
  }

  /// Branding and stores follow whoever is signed in: loaded on sign-in, cleared on sign-out
  /// (the saved store too, when the person signed out on purpose).
  void follow(AuthSession session) {
    session.addListener(() {
      if (session.status == AuthStatus.signedIn) {
        load();
      } else if (session.status == AuthStatus.signedOut) {
        clear(forget: session.signedOutOnPurpose);
      }
    });
  }

  /// Signed out. [forget] also drops the saved store, so the next person starts on the
  /// default one; an expired session keeps it for the same person signing back in.
  void clear({bool forget = true}) {
    _branding = const Branding();
    _locations = const [];
    _selected = null;
    if (forget) {
      _savedId = null;
      _api.locationId = null;
      _save(null);
    }
    _revision++;
    notifyListeners();
  }
}

class ShopScope extends InheritedNotifier<ShopContext> {
  const ShopScope({super.key, required ShopContext shop, required super.child})
    : super(notifier: shop);

  static ShopContext of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShopScope>()!.notifier!;

  static ShopContext read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ShopScope>()!.notifier!;
}
