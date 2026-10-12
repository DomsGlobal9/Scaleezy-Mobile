import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/utils/money.dart';
import 'package:scaleezy/core/view_model/view_model.dart';
import 'package:scaleezy/features/dashboard/data/dashboard_models.dart';
import 'package:scaleezy/features/dashboard/data/dashboard_repository.dart';
import 'package:scaleezy/features/inventory/data/inventory_models.dart';
import 'package:scaleezy/features/inventory/data/inventory_repository.dart';
import 'package:scaleezy/features/orders/data/order_models.dart';
import 'package:scaleezy/features/orders/data/order_repository.dart';
import 'package:scaleezy/features/purchase_orders/data/purchase_order_models.dart';
import 'package:scaleezy/features/purchase_orders/data/purchase_order_repository.dart';

/// What the home screen shows, all of it read from the server in one go.
class HomeData {
  /// The basic counts; null for people who see the money tiles instead.
  final DashboardSummary? summary;

  /// The website's money tiles, for `report:financial`.
  final MoneySummary? money;

  /// Out of stock first, then low (the website's list); null when the role cannot see stock.
  final List<StockAlert>? lowStock;

  /// Null when the role cannot see stock movements.
  final List<TransactionItem>? movements;

  /// Null when the role cannot see orders.
  final List<OrderItemSummary>? orders;

  /// Purchase orders sent or part received, as the purchase orders screen's "To receive"
  /// counts them. Null on the money path or without `purchase_order:view`.
  final int? openPurchaseOrders;

  const HomeData({
    this.summary,
    this.money,
    this.lowStock,
    this.movements,
    this.orders,
    this.openPurchaseOrders,
  });
}

/// One figure at the top. [id] tells the screen which icon, colour and destination it has;
/// [alert] is true when the figure wants attention (it then takes its warning colour).
class HomeTile {
  final String id;
  final String title;
  final String value;
  final String? note;
  final String? secondaryNote;
  final bool alert;

  const HomeTile(
    this.id,
    this.title,
    this.value, {
    this.note,
    this.secondaryNote,
    this.alert = false,
  });
}

/// The dashboard: the summary plus the sections the role is allowed to see, and the numbers
/// drawn from them.
class HomeViewModel extends ViewModel {
  HomeViewModel({
    DashboardRepository? dashboard,
    InventoryRepository? inventory,
    OrderRepository? orders,
    PurchaseOrderRepository? purchaseOrders,
  }) : _dashboard = dashboard ?? DashboardRepository(),
       _inventory = inventory ?? InventoryRepository(),
       _orders = orders ?? OrderRepository(),
       _purchaseOrders = purchaseOrders ?? PurchaseOrderRepository();

  final DashboardRepository _dashboard;
  final InventoryRepository _inventory;
  final OrderRepository _orders;
  final PurchaseOrderRepository _purchaseOrders;

  /// As many movements and alerts as the website's widgets show.
  static const recentCount = 10;

  static final _count = NumberFormat.decimalPattern('en_IN');

  HomeData? _data;
  ApiException? _error;

  /// Null until the first load arrives.
  HomeData? get data => _data;

  /// Kept whole so a 403 shows "no access" rather than a failure.
  ApiException? get error => _error;

  /// The summary is required; the other sections load only when allowed and are skipped
  /// (not failed) when their call fails.
  int _requestId = 0;

  Future<void> load({
    required bool canSeeMoney,
    required bool canViewInventory,
    required bool canViewOrders,
    required bool canViewPurchaseOrders,
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
        canSeeMoney
            ? _dashboard.getMoneySummary()
            : _dashboard.getDashboardSummary(),
        optional(canViewInventory, _dashboard.getStockAlerts),
        optional(
          canViewInventory,
          () => _inventory.getTransactions(limit: recentCount),
        ),
        optional(canViewOrders, () => _orders.getOrders()),
        // The money path has the open PO value already.
        optional(
          canViewPurchaseOrders && !canSeeMoney,
          _purchaseOrders.purchaseOrders,
        ),
      ]);
      if (disposed || id != _requestId) return;
      final head = results[0];
      final alerts = results[1] as List<StockAlert>?;
      final pos = results[4] as List<PurchaseOrderSummary>?;
      _data = HomeData(
        summary: head is DashboardSummary ? head : null,
        money: head is MoneySummary ? head : null,
        lowStock: alerts == null ? null : lowStockFirst(alerts),
        movements: results[2] as List<TransactionItem>?,
        orders: results[3] as List<OrderItemSummary>?,
        openPurchaseOrders: pos?.where((p) => p.canReceive).length,
      );
    } on ApiException catch (e) {
      if (disposed || id != _requestId) return;
      _error = e;
    }
    notifyListeners();
  }

  /// The website's low-stock list: out of stock first, then low, at most [recentCount]; other
  /// kinds of alert are left out.
  static List<StockAlert> lowStockFirst(List<StockAlert> alerts) => [
    ...alerts.where((a) => a.type == 'OUT_OF_STOCK'),
    ...alerts.where((a) => a.type == 'LOW_STOCK'),
  ].take(recentCount).toList();

  // ---- The figures at the top -----------------------------------------------------------------

  /// The website's five money tiles for `report:financial`, else the basic counts. [store] is
  /// the selected store's name: the stock figures are for it alone, so the headline says so.
  List<HomeTile> tiles({String? store}) {
    final d = _data;
    if (d == null) return const [];
    String at(String title) => store == null ? title : '$title · $store';
    String n(num v) => _count.format(v);

    final m = d.money;
    if (m != null) {
      return [
        HomeTile(
          'value',
          at('Inventory value'),
          formatRupees(m.inventoryValue),
          note: m.unitsWithoutCost > 0
              ? '${n(m.unitsWithoutCost)} units have no cost or price recorded and count as ₹0. '
                    'Add a unit cost when you stock in, or a price on the product.'
              : m.unitsValuedAtPrice > 0
              ? '${n(m.unitsValuedAtPrice)} units are valued at their selling price '
                    'because no cost was recorded. Add a unit cost when you stock in for a truer figure.'
              : null,
          secondaryNote: m.companyWideValue == null
              ? null
              : '${formatRupees(m.companyWideValue!)} across all locations',
        ),
        HomeTile('openPoValue', 'Open PO value', formatRupees(m.openPoValue)),
        HomeTile(
          'lowStock',
          'Low stock count',
          n(m.lowStockCount),
          note: m.outOfStockCount > 0
              ? '${n(m.outOfStockCount)} more ${m.outOfStockCount == 1 ? 'is' : 'are'} out of stock.'
              : null,
          alert: m.lowStockCount > 0,
        ),
        HomeTile(
          'deadStock',
          'Dead stock value',
          formatRupees(m.deadStockValue),
          alert: m.deadStockValue > 0,
        ),
        HomeTile('activeProducts', 'Active products', n(m.activeProducts)),
      ];
    }

    final s = d.summary!;
    final value = s.inventoryValue;
    return [
      if (value != null)
        HomeTile('value', at('Inventory value'), formatRupees(value)),
      HomeTile(
        'pieces',
        value == null ? at('Pieces in stock') : 'Pieces in stock',
        n(s.totalUnits),
      ),
      HomeTile(
        'lowStock',
        'Low stock count',
        n(s.criticalStockItems),
        alert: s.criticalStockItems > 0,
      ),
      HomeTile('activeProducts', 'Active products', n(s.activeProducts)),
      if (d.openPurchaseOrders != null)
        HomeTile(
          'openPos',
          'Open purchase orders',
          n(d.openPurchaseOrders!),
          note: 'Sent or part received',
        ),
      HomeTile(
        'onOrder',
        'Pieces on order',
        n(s.pendingReceipts),
        note: 'Ordered, not yet received',
        alert: s.pendingReceipts > 0,
      ),
      HomeTile(
        'suppliers',
        'Suppliers',
        n(s.totalSuppliers),
        note: 'Active suppliers',
      ),
    ];
  }

  // ---- Derived from real data -----------------------------------------------------------------

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// The movement list when the role can see it, else the basic summary's few.
  List<TransactionItem> get recentMovements =>
      _data?.movements ?? _data?.summary?.recentTransactions ?? const [];

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
