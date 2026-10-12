import 'dart:async';

import 'package:intl/intl.dart';

import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/view_model/view_model.dart';
import 'package:scaleezy/features/orders/data/order_models.dart';
import 'package:scaleezy/features/orders/data/order_repository.dart';

/// Sales orders: every status loaded at once, then filtered here by status chip and counter.
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

  String _query = '';
  String _status = 'ALL';
  bool _counterOnly = false;

  List<OrderItemSummary>? _orders;
  String? _error;
  int _req = 0;
  Timer? _debounce;

  String get query => _query;
  String get status => _status;
  bool get counterOnly => _counterOnly;

  /// Null until the first load arrives.
  List<OrderItemSummary>? get orders => _orders;
  String? get error => _error;

  /// Every status comes back at once so each chip can show its count; the chip filters locally.
  Future<void> load() async {
    final id = ++_req;
    _error = null;
    notifyListeners();
    try {
      final orders = await _repo.getOrders(search: _query.trim());
      if (disposed || id != _req) return;
      _orders = orders;
    } on ApiException catch (e) {
      if (disposed || id != _req) return;
      _error = e.message;
    }
    notifyListeners();
  }

  /// Typing searches once the person pauses.
  void search(String text) {
    _query = text;
    notifyListeners();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), load);
  }

  void selectStatus(String status) {
    _status = status;
    notifyListeners();
  }

  void setCounterOnly(bool value) {
    _counterOnly = value;
    notifyListeners();
  }

  // ---- Derived from the loaded orders ---------------------------------------------------------

  /// Loaded orders after the counter filter; what the chip counts are taken from.
  List<OrderItemSummary> get all => (_orders ?? const <OrderItemSummary>[])
      .where((o) => !_counterOnly || o.atCounter)
      .toList();

  /// [all] after the status chip.
  List<OrderItemSummary> get shown =>
      all.where((o) => _status == 'ALL' || o.status == _status).toList();

  /// What the shown orders are worth, leaving out cancelled ones.
  double get value => shown
      .where((o) => o.status != 'CANCELLED')
      .fold<double>(0, (a, o) => a + o.totalAmount);

  int countFor(String status) {
    final all = this.all;
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
