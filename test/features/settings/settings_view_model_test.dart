import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/shop/shop_models.dart';
import 'package:scaleezy/features/settings/presentation/view_models/password_view_model.dart';
import 'package:scaleezy/features/settings/presentation/view_models/settings_view_model.dart';

import '../auth/auth_fakes.dart';
import '../../support/roles.dart';
import 'settings_fakes.dart';

void main() {
  late FakeAuthSession session;
  late TestShop shop;
  late FakeAccountRepository account;
  late FakeShopRepository shopRepo;
  late SettingsViewModel vm;

  setUp(() {
    session = FakeAuthSession(signedIn: person(owner: true));
    shop = TestShop(
      branding: const Branding(
        businessPhone: '98765',
        businessAddress: 'MG Road',
      ),
    );
    account = FakeAccountRepository();
    shopRepo = FakeShopRepository();
    vm = SettingsViewModel(
      session,
      shop,
      account: account,
      shopRepository: shopRepo,
    );
  });

  test('saving a name refreshes the session', () async {
    expect(await vm.saveName('Ravi'), isNull);
    expect(account.calls, ['name:Ravi']);
    expect(session.restores, 1);
    expect(vm.saving, isFalse);
  });

  test('a refused name returns the server message', () async {
    account.fail = 'Name too long.';
    expect(await vm.saveName('Ravi'), 'Name too long.');
    expect(session.restores, 0);
    expect(vm.saving, isFalse);
  });

  test('saving is true while a save is on its way', () async {
    final done = vm.saveShopName('Asha Sarees');
    expect(vm.saving, isTrue);
    await done;
    expect(vm.saving, isFalse);
  });

  test(
    'shop edits clear empty fields, keep the other detail, reload the shop',
    () async {
      await vm.saveShopName('');
      await vm.saveShopPhone('12345');
      await vm.saveShopAddress('');
      expect(shopRepo.calls, [
        {'name': null},
        {'address': 'MG Road', 'phone': '12345'},
        {'address': null, 'phone': '98765'},
      ]);
      expect(shop.loads, 3);
    },
  );

  test('a refused shop edit does not reload the shop', () async {
    shopRepo.fail = 'Only the owner can do that.';
    expect(await vm.saveShopName('X'), 'Only the owner can do that.');
    expect(shop.loads, 0);
  });

  test('signing out other devices reports the server message', () async {
    expect(await vm.signOutOtherDevices(), isNull);
    account.fail = 'Try again later.';
    expect(await vm.signOutOtherDevices(), 'Try again later.');
    expect(account.calls, ['signOutOthers', 'signOutOthers']);
    expect(vm.signingOutOthers, isFalse);
  });

  test('signing out ends the session', () async {
    await vm.signOut();
    expect(session.logouts, 1);
  });

  group('password', () {
    test('too short or not matching never reaches the server', () async {
      final pw = PasswordViewModel(account);
      expect(
        await pw.change('old', 'short', 'short'),
        'The new password must be at least 8 characters.',
      );
      expect(
        await pw.change('old', 'longenough', 'different'),
        'The two new passwords do not match.',
      );
      expect(pw.error, 'The two new passwords do not match.');
      expect(account.calls, isEmpty);
    });

    test('a change sends current and new password', () async {
      final pw = PasswordViewModel(account);
      expect(await pw.change('old', 'longenough', 'longenough'), isNull);
      expect(account.calls, ['password:old>longenough']);
      expect(pw.error, isNull);
      expect(pw.busy, isFalse);
    });

    test('a refused change returns the server message', () async {
      account.fail = 'Current password is wrong.';
      final pw = PasswordViewModel(account);
      expect(
        await pw.change('old', 'longenough', 'longenough'),
        'Current password is wrong.',
      );
      expect(pw.error, 'Current password is wrong.');
      expect(pw.busy, isFalse);
    });
  });
}
