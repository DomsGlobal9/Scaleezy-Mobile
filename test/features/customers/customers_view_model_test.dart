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

    test('loads points and store credit alongside the customer', () async {
      final asked = <String>[];
      final vm = CustomerDetailViewModel(
        'c1',
        FakeCustomerRepository(
          one: (id) async => customer(id),
          points: (id) async {
            asked.add('points $id');
            return const CustomerPoints(enabled: true, points: 120, value: 60);
          },
          credit: (id) async {
            asked.add('credit $id');
            return const StoreCredit(credit: 249.5);
          },
        ),
      );

      await vm.load();
      expect(asked, ['points c1', 'credit c1']);
      expect(vm.full!.id, 'c1');
      expect(vm.points!.points, 120);
      expect(vm.credit!.credit, 249.5);
    });

    test('loyalty off and no credit: both hidden', () async {
      final vm = CustomerDetailViewModel(
        'c1',
        FakeCustomerRepository(
          one: (id) async => customer(id),
          points: (_) async =>
              const CustomerPoints(enabled: false, points: 0, value: 0),
          credit: (_) async => const StoreCredit(credit: 0),
        ),
      );

      await vm.load();
      expect(vm.full, isNotNull);
      expect(vm.points, isNull);
      expect(vm.credit, isNull);
    });

    test('a failed points or credit call still shows the customer', () async {
      final vm = CustomerDetailViewModel(
        'c1',
        FakeCustomerRepository(
          one: (id) async => customer(id),
          credit: (_) async => throw const ApiException('The server is busy.'),
          // points unset: refused (403)
        ),
      );

      await vm.load();
      expect(vm.full!.id, 'c1');
      expect(vm.error, isNull);
      expect(vm.points, isNull);
      expect(vm.credit, isNull);
    });

    test('the customer shows before points arrive', () async {
      final slow = Completer<CustomerPoints>();
      final vm = CustomerDetailViewModel(
        'c1',
        FakeCustomerRepository(
          one: (id) async => customer(id),
          points: (_) => slow.future,
        ),
      );

      final loading = vm.load();
      await pumpEventQueue();
      expect(vm.full!.id, 'c1');
      expect(vm.points, isNull);

      slow.complete(const CustomerPoints(enabled: true, points: 5, value: 5));
      await loading;
      expect(vm.points!.points, 5);
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
