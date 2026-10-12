import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/features/day_book/data/day_book_models.dart';
import 'package:scaleezy/features/day_book/presentation/view_models/day_book_view_model.dart';

import 'day_book_fakes.dart';

/// Answers each date with that day; no date is the shop's today, 12 Oct.
Future<DayBook> _byDate(String? date) async => dayBook(
  date: date ?? '2026-10-12',
  inProgress: date == null || date == '2026-10-12',
);

void main() {
  test('opens on the shop\'s today, for the chosen store', () async {
    final repo = FakeDayBookRepository(_byDate);
    final vm = DayBookViewModel(repo);
    expect(vm.day, isNull);

    await vm.setLocation('l1');

    expect(repo.calls, [(null, 'l1')]);
    expect(vm.book!.date, '2026-10-12');
    expect(vm.day, DateTime(2026, 10, 12));
    expect(vm.canGoForward, isFalse);

    await vm.nextDay();
    expect(repo.calls, hasLength(1));
  });

  test('previous and next day ask for those dates', () async {
    final repo = FakeDayBookRepository(_byDate);
    final vm = DayBookViewModel(repo);
    await vm.load();

    await vm.previousDay();
    expect(repo.calls.last, ('2026-10-11', null));
    expect(vm.book!.inProgress, isFalse);
    expect(vm.canGoForward, isTrue);

    await vm.nextDay();
    expect(repo.calls.last, ('2026-10-12', null));

    await vm.showDay(DateTime(2026, 9, 30, 15, 20));
    expect(repo.calls.last, ('2026-09-30', null));
    expect(vm.day, DateTime(2026, 9, 30));
  });

  test('a new day or store clears the old figures while it loads', () async {
    final pending = Completer<DayBook>();
    var first = true;
    final repo = FakeDayBookRepository((date) {
      if (first) {
        first = false;
        return _byDate(date);
      }
      return pending.future;
    });
    final vm = DayBookViewModel(repo);
    await vm.load();
    expect(vm.book, isNotNull);

    final loading = vm.setLocation('l2');
    expect(vm.book, isNull);
    pending.complete(dayBook());
    await loading;
    expect(vm.book, isNotNull);
  });

  test(
    'a slow answer for an earlier day does not replace a later one',
    () async {
      final slow = Completer<DayBook>();
      final repo = FakeDayBookRepository(
        (date) => date == '2026-10-10' ? slow.future : _byDate(date),
      );
      final vm = DayBookViewModel(repo);

      final stale = vm.showDay(DateTime(2026, 10, 10));
      await vm.showDay(DateTime(2026, 10, 9));
      slow.complete(dayBook(date: '2026-10-10', inProgress: false));
      await stale;

      expect(vm.book!.date, '2026-10-09');
    },
  );

  test('a refusal shows the server\'s words', () async {
    final vm = DayBookViewModel(
      FakeDayBookRepository(
        (_) async => throw const ApiException(
          'Provide a date as YYYY-MM-DD.',
          statusCode: 400,
        ),
      ),
    );
    await vm.load();
    expect(vm.book, isNull);
    expect(vm.error, 'Provide a date as YYYY-MM-DD.');
  });
}
