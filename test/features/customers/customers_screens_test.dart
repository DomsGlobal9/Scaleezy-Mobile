import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/session/auth_session.dart';
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
          : [customer('a', name: 'Asha Rao'), customer('b', name: 'Ravi K')],
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

    await tester.enterText(find.byType(TextField), 'zz');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(repo.searches.last, 'zz');
    expect(find.text('Nobody matches "zz".'), findsOneWidget);
  });

  testWidgets('customer detail shows the loaded customer', (tester) async {
    final vm = CustomerDetailViewModel(
      'c1',
      FakeCustomerRepository(
        one: (id) async => customer(id, name: 'Asha Rao', phone: '9876543210'),
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
}
