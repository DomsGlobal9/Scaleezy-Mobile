import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/shop/shop_context.dart';
import 'package:scaleezy/core/shop/shop_models.dart';
import 'package:scaleezy/core/shop/shop_repository.dart';
import 'package:scaleezy/features/settings/data/account_repository.dart';

import '../auth/auth_fakes.dart';

/// Records each call; throws [fail] as the server's message when set.
class FakeAccountRepository extends AccountRepository {
  FakeAccountRepository() : super(offlineClient());

  String? fail;
  final calls = <String>[];

  Future<void> _answer(String call) async {
    calls.add(call);
    if (fail != null) throw ApiException(fail!);
  }

  @override
  Future<void> updateMyName(String name) => _answer('name:$name');

  @override
  Future<void> changeMyPassword(String currentPassword, String newPassword) =>
      _answer('password:$currentPassword>$newPassword');

  @override
  Future<void> signOutOtherDevices() => _answer('signOutOthers');
}

class FakeShopRepository extends ShopRepository {
  FakeShopRepository() : super(offlineClient());

  String? fail;
  final calls = <Map<String, String?>>[];

  Future<Branding> _answer(Map<String, String?> call) async {
    calls.add(call);
    if (fail != null) throw ApiException(fail!);
    return const Branding();
  }

  @override
  Future<Branding> updateShopName(String? name) => _answer({'name': name});

  @override
  Future<Branding> updateShopDetails({
    String? businessAddress,
    String? businessPhone,
  }) => _answer({'address': businessAddress, 'phone': businessPhone});
}

/// Fixed branding; counts reloads.
class FakeShopContext extends ShopContext {
  FakeShopContext([this._branding = const Branding()]) : super(offlineClient());

  final Branding _branding;
  int loads = 0;

  @override
  Branding get branding => _branding;

  @override
  Future<void> load() async => loads++;
}
