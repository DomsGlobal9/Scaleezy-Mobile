import 'package:intl/intl.dart';

import 'package:scaleezy/core/view_model/view_model.dart';
import 'package:scaleezy/features/day_book/data/day_book_models.dart';
import 'package:scaleezy/features/day_book/data/day_book_repository.dart';

/// One business day of the day book, for one store or all of them.
class DayBookViewModel extends ViewModel {
  DayBookViewModel([DayBookRepository? repo])
    : _repo = repo ?? DayBookRepository();

  final DayBookRepository _repo;
  static final _key = DateFormat('yyyy-MM-dd');

  /// Null means the shop's today, which the server works out from the shop's timezone.
  DateTime? _day;
  String? _locationId;
  DayBook? _book;
  String? _error;
  int _req = 0;

  /// Null while a day loads, so one day's figures never sit under another day's date.
  DayBook? get book => _book;
  String? get error => _error;

  /// The day asked for, or the day the server answered for; null before today first loads.
  DateTime? get day => _day ?? _book?.day;

  /// Today is still running; there is nothing after it.
  bool get canGoForward => _book != null && !_book!.inProgress;

  Future<void> load() async {
    final id = ++_req;
    _error = null;
    notifyListeners();
    try {
      final book = await _repo.getDay(
        date: _day == null ? null : _key.format(_day!),
        locationId: _locationId,
      );
      if (disposed || id != _req) return;
      _book = book;
    } catch (e) {
      if (disposed || id != _req) return;
      _error = e.toString();
    }
    notifyListeners();
  }

  /// The store chosen in the app; null for every store together.
  Future<void> setLocation(String? locationId) {
    _locationId = locationId;
    _book = null;
    return load();
  }

  Future<void> showDay(DateTime day) {
    _day = DateTime(day.year, day.month, day.day);
    _book = null;
    return load();
  }

  Future<void> previousDay() async {
    final d = day;
    if (d != null) await showDay(DateTime(d.year, d.month, d.day - 1));
  }

  Future<void> nextDay() async {
    final d = day;
    if (d != null && canGoForward) {
      await showDay(DateTime(d.year, d.month, d.day + 1));
    }
  }
}
