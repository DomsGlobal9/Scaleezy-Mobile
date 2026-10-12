import 'package:scaleezy/features/day_book/data/day_book_models.dart';
import 'package:scaleezy/features/day_book/data/day_book_repository.dart';

import '../../support/fake_api.dart';
import '../../support/fixtures.dart';

export '../../support/fixtures.dart' show costFields, dayBookJson, withoutCost;

DayBook dayBook({
  String date = '2026-10-12',
  bool inProgress = true,
  bool cost = true,
}) => DayBook.fromJson(
  dayBookJson(date: date, inProgress: inProgress, cost: cost),
);

/// Records each (date, locationId) asked for and answers with [answer].
class FakeDayBookRepository extends DayBookRepository {
  FakeDayBookRepository(this.answer) : super(offlineClient());

  Future<DayBook> Function(String? date) answer;
  final calls = <(String?, String?)>[];

  @override
  Future<DayBook> getDay({String? date, String? locationId}) {
    calls.add((date, locationId));
    return answer(date);
  }
}
