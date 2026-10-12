import 'dart:async';

import 'package:intl/intl.dart';

import 'package:scaleezy/core/view_model/view_model.dart';
import 'package:scaleezy/features/orders/data/order_models.dart';
import 'package:scaleezy/features/orders/data/order_repository.dart';

/// Sales orders: every status loaded at once for the search and "where from", then filtered here
/// by status chip.
class OrdersViewModel extends ViewModel {
  OrdersViewModel([OrderRepository? repo]) : _repo = repo ?? OrderRepository();

  final OrderRepository _repo;
  final _day = DateFormat('EEE, d MMM');

  static const statuses = [
    'ALL',
    'DRAFT',
    'CONFIRMED',
    'PARTIALLY_DISPATCHED',
    'DISPATCHED',
    'CANCELLED',
  ];

  /// The website's "Where from" choices; the key is the server's `source`, '' is anywhere.
  static const sources = {
    '': 'From anywhere',
    'COUNTER': 'Counter',
    'POS': 'POS till',
    'SHOPIFY': 'Shopify',
    'OTHER': 'Other',
  };

  String _query = '';
  String _status = 'ALL';
  String _source = '';

  List<OrderItemSummary>? _orders;
  Object? _error;
  int _req = 0;
  Timer? _debounce;

  String get query => _query;
  String get status => _status;
  String get source => _source;

  /// Null until the first load arrives.
  List<OrderItemSummary>? get orders => _orders;

  /// The failure as caught, so a 403 can show no-access rather than "try again".
  Object? get error => _error;

  /// Every status comes back at once so each chip can show its count; the chip filters locally.
  Future<void> load() async {
    final id = ++_req;
    _error = null;
    notifyListeners();
    try {
      final orders = await _repo.getOrders(
        search: _query.trim(),
        source: _source,
      );
      if (disposed || id != _req) return;
      _orders = orders;
    } catch (e) {
      if (disposed || id != _req) return;
      _error = e;
    }
    notifyListeners();
  }

  /// Typing searches once the person pauses, after 300 ms as the website.
  void search(String text) {
    _query = text;
    notifyListeners();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), load);
  }

  void selectStatus(String status) {
    _status = status;
    notifyListeners();
  }

  /// Where from is asked of the server, like the website's filter.
  Future<void> setSource(String source) {
    _source = source;
    return load();
  }

  // ---- Derived from the loaded orders ---------------------------------------------------------

  List<OrderItemSummary> get _all => _orders ?? const <OrderItemSummary>[];

  /// The loaded orders after the status chip.
  List<OrderItemSummary> get shown =>
      _all.where((o) => _status == 'ALL' || o.status == _status).toList();

  /// What the shown orders are worth, leaving out cancelled ones.
  double get value => shown
      .where((o) => o.status != 'CANCELLED')
      .fold<double>(0, (a, o) => a + o.totalAmount);

  int countFor(String status) {
    final all = _all;
    return status == 'ALL'
        ? all.length
        : all.where((o) => o.status == status).length;
  }

  String dayLabel(DateTime d) {
    final today = _dateOnly(DateTime.now());
    final day = _dateOnly(d);
    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return _day.format(d);
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// The shown orders with a (day label, day total) header before each new day.
  List<Object> get rows {
    final shown = this.shown;
    final rows = <Object>[];
    String? lastDay;
    for (final o in shown) {
      final label = dayLabel(o.date);
      if (label != lastDay) {
        final dayOrders = shown.where(
          (x) => dayLabel(x.date) == label && x.status != 'CANCELLED',
        );
        rows.add((
          label,
          dayOrders.fold<double>(0, (a, x) => a + x.totalAmount),
        ));
        lastDay = label;
      }
      rows.add(o);
    }
    return rows;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
