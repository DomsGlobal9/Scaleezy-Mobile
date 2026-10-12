import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/features/customers/data/customer_models.dart';
import 'package:scaleezy/features/customers/presentation/view_models/customer_detail_view_model.dart';
import 'package:scaleezy/features/customers/presentation/view_models/customer_form_view_model.dart';
import 'package:scaleezy/features/customers/presentation/view_models/customers_view_model.dart';

import '../../support/fixtures.dart';
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
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(repo.searches, isEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 100));

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

      final error = await vm.save(name: 'Ravi', phone: '9848022338', email: '');

      expect(error, isNull);
      expect(vm.saved!.id, 'n1');
      expect(vm.busy, isTrue); // the form closes
      // Sent in its stored form, as the website's normalisePhone.
      expect(repo.saves.single, {
        'op': 'create',
        'name': 'Ravi',
        'phone': '+919848022338',
        'email': '',
      });
    });

    test('a phone or email that does not look right is not sent', () async {
      final repo = FakeCustomerRepository(
        saveAnswer: () async => customer('n1'),
      );
      final vm = CustomerFormViewModel(null, repo);

      expect(
        await vm.save(name: 'Ravi', phone: '12345', email: ''),
        'Enter a 10-digit mobile number, or + and the country code for a number from another country.',
      );
      expect(
        await vm.save(name: 'Ravi', phone: '98480 22338', email: 'ravi@shop'),
        "That email address doesn't look right. Check it, or leave the box empty.",
      );
      expect(repo.saves, isEmpty);
      expect(vm.busy, isFalse);
    });

    test(
      'a customer saved without a phone can be edited without one',
      () async {
        final repo = FakeCustomerRepository(
          saveAnswer: () async => customer('c1'),
        );
        final vm = CustomerFormViewModel(customer('c1'), repo);
        expect(vm.phoneOptional, isTrue);

        expect(await vm.save(name: 'Asha', phone: ' ', email: ''), isNull);
        expect(repo.saves.single['phone'], isNull);
      },
    );

    test('a number someone already has offers to open them', () async {
      final asked = <String>[];
      final repo = FakeCustomerRepository(
        saveAnswer: () async => throw ApiException(
          'Priya Sharma (CUS-p1) is already saved with that number.',
          statusCode: 409,
          // customer.controller.ts `taken`: who has it, at the top level.
          body: phoneTakenFields('p1'),
        ),
        byPhone: (phone) async {
          asked.add(phone);
          return null;
        },
      );
      final vm = CustomerFormViewModel(null, repo);

      final error = await vm.save(
        name: 'Ravi',
        phone: '+91 98480 22338',
        email: '',
      );

      expect(error, contains('already saved with that number'));
      expect(asked, isEmpty); // named in the answer: no lookup
      expect(
        (vm.taken!.id, vm.taken!.name, vm.taken!.code),
        ('p1', 'Priya Sharma', 'CUS-p1'),
      );
      expect(vm.busy, isFalse);
    });

    test('the holder in details (PHONE_TAKEN) is read too', () async {
      final repo = FakeCustomerRepository(
        saveAnswer: () async => throw ApiException(
          'Priya Sharma (CUS-p1) is already saved with that number.',
          statusCode: 409,
          details: {'code': 'PHONE_TAKEN', ...phoneTakenFields('p1')},
        ),
      );
      final vm = CustomerFormViewModel(null, repo);
      await vm.save(name: 'Ravi', phone: '9848022338', email: '');
      expect(vm.taken!.id, 'p1');
    });

    test('a 409 that names nobody looks the number up', () async {
      final asked = <String>[];
      final repo = FakeCustomerRepository(
        saveAnswer: () async => throw const ApiException(
          'Priya Sharma (CUS-000041) is already saved with that number.',
          statusCode: 409,
        ),
        byPhone: (phone) async {
          asked.add(phone);
          return customer('p1', name: 'Priya Sharma');
        },
      );
      final vm = CustomerFormViewModel(null, repo);

      await vm.save(name: 'Ravi', phone: '+91 98480 22338', email: '');

      expect(asked, ['+919848022338']);
      expect(vm.taken!.name, 'Priya Sharma');
    });

    test(
      'editing a customer is never told they hold their own number',
      () async {
        final repo = FakeCustomerRepository(
          saveAnswer: () async => throw ApiException(
            'Asha Rao (CUS-c1) is already saved with that number.',
            statusCode: 409,
            body: phoneTakenFields('c1', name: 'Asha Rao'),
          ),
        );
        final vm = CustomerFormViewModel(customer('c1'), repo);
        await vm.save(name: 'Asha', phone: '9848022338', email: '');
        expect(vm.taken, isNull);
      },
    );

    test('an existing customer is updated', () async {
      final repo = FakeCustomerRepository(
        saveAnswer: () async => customer('c1', name: 'Asha R'),
      );
      final vm = CustomerFormViewModel(customer('c1'), repo);

      expect(
        await vm.save(name: 'Asha R', phone: '9848022338', email: 'a@b.in'),
        isNull,
      );
      expect(repo.saves.single['op'], 'update');
      expect(repo.saves.single['id'], 'c1');
      expect(repo.saves.single['phone'], '+919848022338');
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
          phone: '9848022338',
          email: '',
        );

        expect(error, 'That phone number is already used.');
        expect(vm.error, error);
        expect(vm.busy, isFalse);
        expect(vm.saved, isNull);
        expect(vm.taken, isNull); // not a 409: nobody to offer
      },
    );
  });
}
