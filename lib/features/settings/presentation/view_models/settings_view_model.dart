import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/shop/shop_context.dart';
import 'package:scaleezy/core/shop/shop_repository.dart';
import 'package:scaleezy/core/view_model/view_model.dart';
import 'package:scaleezy/features/settings/data/account_repository.dart';

/// Settings: the person's own name and devices, and (for the owner) the shop's details. Each
/// save refreshes the session or shop so the change shows everywhere.
class SettingsViewModel extends ViewModel {
  SettingsViewModel(
    this._session,
    this._shop, {
    AccountRepository? account,
    ShopRepository? shopRepository,
  }) : _account = account ?? AccountRepository(),
       _shopRepository = shopRepository ?? ShopRepository();

  final AuthSession _session;
  final ShopContext _shop;
  final AccountRepository _account;
  final ShopRepository _shopRepository;

  bool _saving = false;
  bool _signingOutOthers = false;

  /// An edit sheet's save is on its way.
  bool get saving => _saving;
  bool get signingOutOthers => _signingOutOthers;

  /// The backend the app talks to, for the App section.
  String get serverHost => Uri.parse(kApiBaseUrl).host;

  // Each action below returns null on success, otherwise the server's message.

  Future<String?> saveName(String name) => _save(() async {
    await _account.updateMyName(name);
    await _session.restore(); // pick up the new name everywhere
  });

  /// Owner only. Empty clears it.
  Future<String?> saveShopName(String name) => _save(() async {
    await _shopRepository.updateShopName(name.isEmpty ? null : name);
    await _shop.load();
  });

  /// Owner only. Empty clears it; the address is sent back unchanged.
  Future<String?> saveShopPhone(String phone) => _save(() async {
    await _shopRepository.updateShopDetails(
      businessPhone: phone.isEmpty ? null : phone,
      businessAddress: _shop.branding.businessAddress,
    );
    await _shop.load();
  });

  /// Owner only. Empty clears it; the phone is sent back unchanged.
  Future<String?> saveShopAddress(String address) => _save(() async {
    await _shopRepository.updateShopDetails(
      businessAddress: address.isEmpty ? null : address,
      businessPhone: _shop.branding.businessPhone,
    );
    await _shop.load();
  });

  Future<String?> signOutOtherDevices() async {
    _signingOutOthers = true;
    notifyListeners();
    String? error;
    try {
      await _account.signOutOtherDevices();
    } on ApiException catch (e) {
      error = e.message;
    }
    _signingOutOthers = false;
    notifyListeners();
    return error;
  }

  Future<void> signOut() => _session.logout();

  Future<String?> _save(Future<void> Function() action) async {
    _saving = true;
    notifyListeners();
    String? error;
    try {
      await action();
    } on ApiException catch (e) {
      error = e.message;
    }
    _saving = false;
    notifyListeners();
    return error;
  }
}
