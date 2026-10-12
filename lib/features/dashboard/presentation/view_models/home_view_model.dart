import 'package:flutter/foundation.dart';

import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/view_model/view_model.dart';
import 'package:scaleezy/features/dashboard/data/dashboard_models.dart';
import 'package:scaleezy/features/dashboard/data/dashboard_repository.dart';
import 'package:scaleezy/features/inventory/data/inventory_models.dart';
import 'package:scaleezy/features/inventory/data/inventory_repository.dart';
import 'package:scaleezy/features/orders/data/order_models.dart';
import 'package:scaleezy/features/orders/data/order_repository.dart';
import 'package:scaleezy/features/products/data/product_models.dart';

/// What the home screen shows, all of it read from the server in one go.
class HomeData {
  final DashboardSummary summary;
  final List<VariantItem> lowStock;

  /// Null when the role cannot see stock movements.
  final List<TransactionItem>? movements;

  /// Null when the role cannot see orders.
  final List<OrderItemSummary>? orders;

  const HomeData(this.summary, this.lowStock, this.movements, this.orders);
}

/// The dashboard: the summary plus the sections the role is allowed to see, and the numbers
/// drawn from them.
class HomeViewModel extends ViewModel {
  HomeViewModel({
    DashboardRepository? dashboard,
    InventoryRepository? inventory,
    OrderRepository? orders,
  }) : _dashboard = dashboard ?? DashboardRepository(),
       _inventory = inventory ?? InventoryRepository(),
       _orders = orders ?? OrderRepository();

  final DashboardRepository _dashboard;
  final InventoryRepository _inventory;
  final OrderRepository _orders;

  static const movementSample = 200;

  HomeData? _data;
  String? _error;

  /// Null until the first load arrives.
  HomeData? get data => _data;
  String? get error => _error;

  /// The summary is required; the other sections load only when allowed and are skipped
  /// (not failed) when their call fails.
  int _requestId = 0;

  Future<void> load({
    required bool canViewInventory,
    required bool canViewOrders,
  }) async {
    // A store switch mid-load starts another load; only the newest one may land.
    final id = ++_requestId;
    _error = null;
    notifyListeners();
    Future<T?> optional<T>(bool allowed, Future<T> Function() call) => allowed
        ? call().then<T?>((v) => v).catchError((Object e) {
            debugPrint('Home: optional section skipped: $e');
            return null;
          })
        : Future.value(null);

    try {
      final results = await Future.wait<Object?>([
        _dashboard.getDashboardSummary(),
        optional(
          canViewInventory,
          () => _inventory.getLowStockVariants(limit: 6),
        ),
        optional(
          canViewInventory,
          () => _inventory.getTransactions(limit: movementSample),
        ),
        optional(canViewOrders, () => _orders.getOrders()),
      ]);
      if (disposed || id != _requestId) return;
      _data = HomeData(
        results[0] as DashboardSummary,
        (results[1] as List<VariantItem>?) ?? const [],
        results[2] as List<TransactionItem>?,
        results[3] as List<OrderItemSummary>?,
      );
    } on ApiException catch (e) {
      if (disposed || id != _requestId) return;
      _error = e.message;
    }
    notifyListeners();
  }

  // ---- Derived from real data -----------------------------------------------------------------

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Pieces in and out per day for the last seven days, oldest first; null without movements.
  List<({DateTime day, int inQty, int outQty})>? get lastSevenDays {
    final movements = _data?.movements;
    if (movements == null) return null;
    final today = _dateOnly(DateTime.now());
    return List.generate(7, (i) {
      final day = today.subtract(Duration(days: 6 - i));
      var inQty = 0, outQty = 0;
      for (final m in movements) {
        if (!_sameDay(m.timestamp, day)) continue;
        if (m.quantity > 0) {
          inQty += m.quantity;
        } else {
          outQty += -m.quantity;
        }
      }
      return (day: day, inQty: inQty, outQty: outQty);
    });
  }

  int get flowIn => lastSevenDays?.fold<int>(0, (a, f) => a + f.inQty) ?? 0;

  int get flowOut => lastSevenDays?.fold<int>(0, (a, f) => a + f.outQty) ?? 0;

  // Only 200 movements come back; if even those are all from this week, the chart is partial.
  bool get flowTruncated {
    final movements = _data?.movements;
    return movements != null &&
        movements.length >= movementSample &&
        movements.last.timestamp.isAfter(
          DateTime.now().subtract(const Duration(days: 7)),
        );
  }

  /// The movement list when the role can see it, else the summary's few.
  List<TransactionItem> get recentMovements =>
      _data?.movements ?? _data?.summary.recentTransactions ?? const [];

  /// Today's orders that were not cancelled.
  List<OrderItemSummary> get todayOrders => (_data?.orders ?? const [])
      .where((o) => _sameDay(o.date, DateTime.now()) && o.status != 'CANCELLED')
      .toList();

  double get todayTakings =>
      todayOrders.fold<double>(0, (a, o) => a + o.totalAmount);

  int get todayPieces => todayOrders.fold<int>(0, (a, o) => a + o.itemCount);

  int get drafts =>
      (_data?.orders ?? const []).where((o) => o.status == 'DRAFT').length;
}
