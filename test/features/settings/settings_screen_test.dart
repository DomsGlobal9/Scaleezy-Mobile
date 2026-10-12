import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/shop/shop_context.dart';
import 'package:scaleezy/core/shop/shop_models.dart';
import 'package:scaleezy/features/settings/presentation/settings_screen.dart';
import 'package:scaleezy/features/settings/presentation/view_models/settings_view_model.dart';

import '../auth/auth_fakes.dart';
import 'settings_fakes.dart';

void main() {
  late FakeAccountRepository account;
  late FakeShopRepository shopRepo;

  Future<void> pump(WidgetTester tester, {required bool owner}) async {
    // Tall enough that every section is built.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    account = FakeAccountRepository();
    shopRepo = FakeShopRepository();
    final session = FakeAuthSession(signedIn: person(owner: owner));
    final shop = FakeShopContext(const Branding(businessName: 'Asha Sarees'));
    final vm = SettingsViewModel(
      session,
      shop,
      account: account,
      shopRepository: shopRepo,
    );
    await tester.pumpWidget(
      SessionScope(
        session: session,
        child: ShopScope(
          shop: shop,
          child: MaterialApp(home: SettingsScreen(viewModel: vm)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> editName(WidgetTester tester, String name) async {
    await tester.tap(find.text('Name'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), name);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  testWidgets('saving a name closes the sheet and says so', (tester) async {
    await pump(tester, owner: true);
    expect(find.text('SHOP (YOU CAN EDIT)'), findsOneWidget);

    await editName(tester, '  Ravi ');
    expect(account.calls, ['name:Ravi']);
    expect(find.text('Save'), findsNothing);
    expect(find.text('Saved.'), findsOneWidget);
  });

  testWidgets('a refused save stays open with the server message', (
    tester,
  ) async {
    await pump(tester, owner: true);
    account.fail = 'Name too long.';

    await editName(tester, 'Ravi');
    expect(find.text('Name too long.'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('only the owner can edit the shop name', (tester) async {
    await pump(tester, owner: false);
    expect(find.text('SHOP'), findsOneWidget);

    await tester.tap(find.text('Asha Sarees'));
    await tester.pumpAndSettle();
    expect(find.text('Save'), findsNothing);
    expect(shopRepo.calls, isEmpty);
  });
}
