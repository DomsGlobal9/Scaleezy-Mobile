import 'package:flutter/widgets.dart';

import '../models/inventory_models.dart';
import 'api_client.dart';
import 'api_repository.dart';

/// The shop around the signed-in person: its name and logo, its stores, and which store the
/// app is looking at. Changing the store bumps [revision] so screens know to reload.
class ShopContext extends ChangeNotifier {
  ShopContext(this._api) : _repo = ApiRepository(_api);

  final ApiClient _api;
  final ApiRepository _repo;

  Branding _branding = const Branding();
  List<StockLocation> _locations = const [];
  StockLocation? _selected;
  int _revision = 0;

  Branding get branding => _branding;
  List<StockLocation> get locations => _locations;

  /// Null means every store together.
  StockLocation? get selectedLocation => _selected;
  int get revision => _revision;

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
    }
    notifyListeners();
  }

  void selectLocation(StockLocation? location) {
    if (location?.id == _selected?.id) return;
    _selected = location;
    _api.locationId = location?.id;
    _revision++;
    notifyListeners();
  }

  void clear() {
    _branding = const Branding();
    _locations = const [];
    _selected = null;
    _api.locationId = null;
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
