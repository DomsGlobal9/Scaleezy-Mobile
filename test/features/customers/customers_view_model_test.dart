import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/features/customers/data/customer_models.dart';
import 'package:scaleezy/features/customers/presentation/view_models/customer_detail_view_model.dart';
import 'package:scaleezy/features/customers/presentation/view_models/customer_form_view_model.dart';
import 'package:scaleezy/features/customers/presentation/view_models/customers_view_model.dart';

import 'customers_fakes.dart';

void main() {
  group('CustomersViewModel', () {
    test('load fills the list; a failure shows the server message', () async {
      var fail = false;
      final repo = FakeCustomerRepository(
        list: (_) async => fail
            ? throw const ApiException('The server is busy.')
            : [customer('a'), customer('b')],
      );
      final vm = CustomersViewModel(repo);
      expect(vm.customers, isNull);

      await vm.load();
      expect(vm.customers!.map((c) => c.id), ['a', 'b']);
      expect(vm.error, isNull);

      fail = true;
      await vm.load();
      expect(vm.error, 'The server is busy.');
      expect(vm.customers, hasLength(2)); // keeps what it had
    });

    test('typing searches once, after a pause', () async {
      final repo = FakeCustomerRepository(list: (_) async => []);
      final vm = CustomersViewModel(repo);

      vm.search('as');
      vm.search('asha');
      expect(vm.query, 'asha');
      expect(repo.searches, isEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 450));

      expect(repo.searches, ['asha']);
      vm.dispose();
    });

    test('an answer that arrives after a newer load is dropped', () async {
      final slow = Completer<List<Customer>>();
      var call = 0;
      final repo = FakeCustomerRepository(
        list: (_) =>
            ++call == 1 ? slow.future : Future.value([customer('new')]),
      );
      final vm = CustomersViewModel(repo);

      final first = vm.load();
      await vm.load();
      slow.complete([customer('old')]);
      await first;

      expect(vm.customers!.map((c) => c.id), ['new']);
    });
  });

  group('CustomerDetailViewModel', () {
    test('loads the customer, or shows the server message', () async {
      var fail = true;
      final repo = FakeCustomerRepository(
        one: (id) async =>
            fail ? throw const ApiException('Not found.') : customer(id),
      );
      final vm = CustomerDetailViewModel('c1', repo);

      await vm.load();
      expect(vm.error, 'Not found.');
      expect(vm.full, isNull);

      fail = false;
      await vm.load();
      expect(vm.error, isNull);
      expect(vm.full!.id, 'c1');
    });
  });

  group('CustomerFormViewModel', () {
    test('a new customer is created and kept for the caller', () async {
      final repo = FakeCustomerRepository(
        saveAnswer: () async => customer('n1', name: 'Ravi'),
      );
      final vm = CustomerFormViewModel(null, repo);

      final error = await vm.save(name: 'Ravi', phone: '9876543210', email: '');

      expect(error, isNull);
      expect(vm.saved!.id, 'n1');
      expect(vm.busy, isTrue); // the form closes
      expect(repo.saves.single, {
        'op': 'create',
        'name': 'Ravi',
        'phone': '9876543210',
        'email': '',
      });
    });

    test('an existing customer is updated', () async {
      final repo = FakeCustomerRepository(
        saveAnswer: () async => customer('c1', name: 'Asha R'),
      );
      final vm = CustomerFormViewModel(customer('c1'), repo);

      expect(
        await vm.save(name: 'Asha R', phone: '9876543210', email: 'a@b.in'),
        isNull,
      );
      expect(repo.saves.single['op'], 'update');
      expect(repo.saves.single['id'], 'c1');
      expect(vm.saved!.name, 'Asha R');
    });

    test(
      'a failed save returns the server message and frees the form',
      () async {
        final repo = FakeCustomerRepository(
          saveAnswer: () async =>
              throw const ApiException('That phone number is already used.'),
        );
        final vm = CustomerFormViewModel(null, repo);

        final error = await vm.save(
          name: 'Ravi',
          phone: '9876543210',
          email: '',
        );

        expect(error, 'That phone number is already used.');
        expect(vm.error, error);
        expect(vm.busy, isFalse);
        expect(vm.saved, isNull);
      },
    );
  });
}
