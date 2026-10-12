import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/features/customers/data/customer_models.dart';
import 'package:scaleezy/features/customers/presentation/customers_screen.dart';
import 'package:scaleezy/features/customers/presentation/view_models/customer_detail_view_model.dart';
import 'package:scaleezy/features/customers/presentation/view_models/customers_view_model.dart';

import 'customers_fakes.dart';

void main() {
  testWidgets('customers screen shows what its view model loads', (
    tester,
  ) async {
    final repo = FakeCustomerRepository(
      list: (search) async => search == 'zz'
          ? []
          : [
              customer('a', name: 'Asha Rao', phone: '+919848022338'),
              customer('b', name: 'Ravi K'),
            ],
    );
    final vm = CustomersViewModel(repo);
    await tester.pumpWidget(
      SessionScope(
        session: AuthSession(offlineClient()),
        child: MaterialApp(home: CustomersScreen(viewModel: vm)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Asha Rao'), findsOneWidget);
    expect(find.text('2 people'), findsOneWidget);
    expect(find.text('+91 98480 22338 · CUS-a'), findsOneWidget);
    expect(find.text('No phone · CUS-b'), findsOneWidget);
    expect(find.text('Active'), findsNWidgets(2));

    await tester.enterText(find.byType(TextField), 'zz');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(repo.searches.last, 'zz');
    expect(find.text('No customers found.'), findsOneWidget);
  });

  testWidgets('customer detail shows the loaded customer', (tester) async {
    final vm = CustomerDetailViewModel(
      'c1',
      FakeCustomerRepository(
        one: (id) async =>
            customer(id, name: 'Asha Rao', phone: '+919876543210'),
      ),
    );
    await tester.pumpWidget(
      SessionScope(
        session: AuthSession(offlineClient()),
        child: MaterialApp(
          home: CustomerDetailScreen(customerId: 'c1', viewModel: vm),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Asha Rao'), findsOneWidget);
    expect(find.text('CUS-c1'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('+91 98765 43210'), findsOneWidget);
  });

  testWidgets('customer detail shows points and store credit', (tester) async {
    final vm = CustomerDetailViewModel(
      'c1',
      FakeCustomerRepository(
        one: (id) async => customer(id, name: 'Asha Rao'),
        points: (_) async => CustomerPoints(
          enabled: false,
          points: 1250,
          value: 625,
          lapsesOn: DateTime(2027, 10, 10),
          entries: [
            BalanceEntry(
              id: 'e1',
              label: 'Used on a bill',
              change: -200,
              reference: 'SO-2026-0042',
              at: DateTime(2026, 10, 10),
            ),
          ],
        ),
        credit: (_) async => StoreCredit(
          credit: 349.5,
          entries: [
            BalanceEntry(
              id: 's1',
              label: 'From a return',
              change: 499.5,
              reference: 'RET-0007',
              at: DateTime(2026, 10, 1),
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(
      SessionScope(
        session: AuthSession(offlineClient()),
        child: MaterialApp(
          home: CustomerDetailScreen(customerId: 'c1', viewModel: vm),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Points & store credit'), findsOneWidget);
    expect(find.text('1,250'), findsOneWidget);
    expect(find.text('points, worth ₹625'), findsOneWidget);
    expect(find.text('Lapse 10 Oct 2027 unless they visit'), findsOneWidget);
    expect(
      find.text('Loyalty points are switched off for the shop.'),
      findsOneWidget,
    );
    expect(find.text('Used on a bill · SO-2026-0042'), findsOneWidget);
    expect(find.text('-200'), findsOneWidget);
    expect(find.text('₹349.50'), findsOneWidget);
    expect(find.text('From a return · RET-0007'), findsOneWidget);
    expect(find.text('+₹499.50'), findsOneWidget);
  });

  testWidgets('a 403 shows no access instead of an error', (tester) async {
    final vm = CustomersViewModel(
      FakeCustomerRepository(
        list: (_) async => throw const ApiException(
          'Seeing customers is not part of your role.',
          statusCode: 403,
        ),
      ),
    );
    await tester.pumpWidget(
      SessionScope(
        session: AuthSession(offlineClient()),
        child: MaterialApp(home: CustomersScreen(viewModel: vm)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsNothing);
    expect(find.text('Not part of your role'), findsOneWidget);
  });

  for (final (name, theme) in [
    ('light', AppTheme.light),
    ('dark', AppTheme.dark),
  ]) {
    testWidgets('customer screens render in the $name theme', (tester) async {
      final repo = FakeCustomerRepository(
        list: (_) async => [
          customer('a', name: 'Asha Rao', phone: '+919848022338'),
          customer('b', name: 'Ravi K'),
        ],
        one: (id) async => Customer.fromJson({
          'id': id,
          'customerCode': 'CUS-$id',
          'name': 'Asha Rao',
          'phone': '+919848022338',
          'email': 'asha@shop.in',
          'status': 'INACTIVE',
          'tags': ['VIP'],
          'salesOrders': [
            {
              'id': 'o1',
              'orderNumber': 'SO-1',
              'status': 'PARTIALLY_DISPATCHED',
              'totalAmount': '1200',
              'createdAt': '2026-10-01T00:00:00Z',
            },
          ],
        }),
        points: (_) async =>
            const CustomerPoints(enabled: true, points: 50, value: 25),
      );
      Widget app(Widget home) => SessionScope(
        session: AuthSession(offlineClient()),
        child: MaterialApp(theme: theme, home: home),
      );

      await tester.pumpWidget(
        app(CustomersScreen(viewModel: CustomersViewModel(repo))),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Asha Rao'), findsOneWidget);

      await tester.pumpWidget(
        app(
          CustomerDetailScreen(
            customerId: 'c1',
            viewModel: CustomerDetailViewModel('c1', repo),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Inactive'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Partly sent'), 300);
      expect(tester.takeException(), isNull);
    });
  }
}
