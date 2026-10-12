import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/session/auth_session.dart';
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
}
