import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/features/dashboard/data/dashboard_models.dart';
import 'package:scaleezy/features/dashboard/presentation/view_models/home_view_model.dart';

import '../orders/orders_fakes.dart';
import '../purchase_orders/purchase_orders_fakes.dart' as po;
import 'dashboard_fakes.dart';

void main() {
  final now = DateTime.now();
  final yesterday = DateTime(now.year, now.month, now.day - 1, 12);

  Future<HomeViewModel> loaded({
    required FakeDashboardRepository dashboard,
    bool money = false,
    bool inventory = false,
    bool orders = false,
    bool purchaseOrders = false,
    po.FakePurchaseOrderRepository? poRepo,
  }) async {
    final vm = HomeViewModel(
      dashboard: dashboard,
      inventory: FakeHomeInventoryRepository(movements: () async => []),
      orders: FakeOrderRepository(answer: () async => []),
      purchaseOrders: poRepo ?? po.FakePurchaseOrderRepository(),
    );
    await vm.load(
      canSeeMoney: money,
      canViewInventory: inventory,
      canViewOrders: orders,
      canViewPurchaseOrders: purchaseOrders,
    );
    return vm;
  }

  test('with every basic permission, all the calls go out together', () async {
    final pending = Completer<DashboardSummary>();
    final dashboard = FakeDashboardRepository(
      () => pending.future,
      alerts: () async => [
        alert('l1', 'LOW_STOCK', quantity: 2),
        alert('o1', 'OUT_OF_STOCK', quantity: 0),
        alert('n1', 'ONLINE_ORDER'),
      ],
    );
    final inventory = FakeHomeInventoryRepository(
      movements: () async => [
        movement('m1', 5, now),
        movement('m2', -3, now),
        movement('m3', 2, yesterday),
      ],
    );
    final orders = FakeOrderRepository(
      answer: () async => [
        order('a', total: 500, pieces: 2),
        order('b', total: 300, status: 'CANCELLED'),
        order('c', total: 200, status: 'DRAFT', date: yesterday),
      ],
    );
    final pos = po.FakePurchaseOrderRepository(
      list: () async => [
        po.summary('d', status: 'DRAFT'),
        po.summary('s', status: 'SENT'),
        po.summary('p', status: 'PARTIALLY_RECEIVED'),
        po.summary('r', status: 'RECEIVED'),
      ],
    );
    final vm = HomeViewModel(
      dashboard: dashboard,
      inventory: inventory,
      orders: orders,
      purchaseOrders: pos,
    );

    final loading = vm.load(
      canSeeMoney: false,
      canViewInventory: true,
      canViewOrders: true,
      canViewPurchaseOrders: true,
    );
    // The optional calls do not wait for the summary.
    expect(dashboard.calls, ['summary', 'alerts']);
    expect(inventory.calls, ['transactions:${HomeViewModel.recentCount}']);
    expect(orders.searches, [null]);
    pending.complete(summary());
    await loading;

    final d = vm.data!;
    expect(d.money, isNull);
    // Out of stock first, then low; other kinds of alert left out (#23).
    expect(d.lowStock!.map((a) => a.id), ['o1', 'l1']);
    expect(d.movements, hasLength(3));
    expect(d.orders, hasLength(3));
    // Drafts are not open: the count matches the purchase orders screen's "To receive".
    expect(d.openPurchaseOrders, 2);
    expect(vm.recentMovements, hasLength(3));

    expect(vm.todayOrders.map((o) => o.id), ['a']);
    expect(vm.todayTakings, 500);
    expect(vm.todayPieces, 2);
    expect(vm.drafts, 1);
  });

  test('the low-stock list keeps at most ten', () {
    final many = [for (var i = 0; i < 14; i++) alert('a$i', 'LOW_STOCK')];
    expect(HomeViewModel.lowStockFirst(many), hasLength(10));
  });

  test('without permissions only the summary is asked for', () async {
    final dashboard = FakeDashboardRepository(
      () async => summary(recent: [movementJson('r1', 4, now)]),
    );
    final vm = await loaded(dashboard: dashboard);

    expect(dashboard.calls, ['summary']);
    expect(vm.data!.lowStock, isNull);
    expect(vm.data!.movements, isNull);
    expect(vm.data!.orders, isNull);
    expect(vm.data!.openPurchaseOrders, isNull);
    // The summary's own few movements fill in.
    expect(vm.recentMovements.map((m) => m.id), ['r1']);
  });

  test(
    'basic tiles: the headline names the store; no PO tile without access',
    () async {
      final vm = await loaded(
        dashboard: FakeDashboardRepository(
          () async => summary(totalUnits: 1250),
        ),
      );
      final tiles = vm.tiles(store: 'Main Store');

      expect(tiles.map((t) => t.id), [
        'pieces',
        'lowStock',
        'activeProducts',
        'onOrder',
        'suppliers',
      ]);
      expect(tiles.first.title, 'Pieces in stock · Main Store');
      expect(tiles.first.value, '1,250');
    },
  );

  test(
    'basic tiles with cost: value first, open POs as the PO screen counts them',
    () async {
      final vm = await loaded(
        dashboard: FakeDashboardRepository(
          () async => summary(inventoryValue: '45000.00'),
        ),
        purchaseOrders: true,
        poRepo: po.FakePurchaseOrderRepository(
          list: () async => [
            po.summary('d', status: 'DRAFT'),
            po.summary('s', status: 'SENT'),
          ],
        ),
      );
      final tiles = vm.tiles(store: 'Main Store');

      expect(tiles.first.title, 'Inventory value · Main Store');
      expect(tiles.first.value, '₹45,000');
      expect(tiles[1].title, 'Pieces in stock');
      final open = tiles.singleWhere((t) => t.id == 'openPos');
      expect((open.title, open.value), ('Open purchase orders', '1'));
    },
  );

  test(
    'report:financial gets the website money tiles, not the basic summary',
    () async {
      final dashboard = FakeDashboardRepository(
        () async => summary(),
        moneyAnswer: () async => money(
          companyWideValue: '414797.00',
          unitsWithoutCost: 12,
          outOfStockCount: 1,
        ),
      );
      final pos = po.FakePurchaseOrderRepository();
      final vm = await loaded(
        dashboard: dashboard,
        money: true,
        purchaseOrders: true,
        poRepo: pos,
      );

      // The money path has the open PO value already: no PO list is fetched.
      expect(dashboard.calls, ['money']);
      expect(vm.data!.summary, isNull);
      final tiles = vm.tiles(store: 'Main Store');
      expect(tiles.map((t) => t.title), [
        'Inventory value · Main Store',
        'Open PO value',
        'Low stock count',
        'Dead stock value',
        'Active products',
      ]);
      expect(tiles[0].value, '₹2,07,398.50');
      expect(
        tiles[0].note,
        '12 units have no cost or price recorded and count as ₹0. '
        'Add a unit cost when you stock in, or a price on the product.',
      );
      expect(tiles[0].secondaryNote, '₹4,14,797 across all locations');
      expect(tiles[1].value, '₹12,000');
      expect(tiles[2].note, '1 more is out of stock.');
      expect(tiles[2].alert, isTrue);
      expect(tiles[3].alert, isFalse);
      expect(tiles[4].value, '42');
    },
  );

  test('money notes: priced-only stock, several sold out, one store', () async {
    final vm = await loaded(
      dashboard: FakeDashboardRepository(
        () async => summary(),
        moneyAnswer: () async =>
            money(unitsValuedAtPrice: 5, outOfStockCount: 3),
      ),
      money: true,
    );
    final tiles = vm.tiles();

    expect(tiles[0].title, 'Inventory value');
    expect(
      tiles[0].note,
      startsWith('5 units are valued at their selling price'),
    );
    expect(tiles[0].secondaryNote, isNull);
    expect(tiles[2].note, '3 more are out of stock.');
  });

  test('a failed optional section is skipped, not an error', () async {
    final vm = HomeViewModel(
      dashboard: FakeDashboardRepository(
        () async => summary(),
        alerts: () async => throw const ApiException('No access.'),
      ),
      inventory: FakeHomeInventoryRepository(
        movements: () async => throw const ApiException('No access.'),
      ),
      orders: FakeOrderRepository(answer: () async => []),
      purchaseOrders: po.FakePurchaseOrderRepository(),
    );

    await vm.load(
      canSeeMoney: false,
      canViewInventory: true,
      canViewOrders: true,
      canViewPurchaseOrders: false,
    );

    expect(vm.error, isNull);
    expect(vm.data!.lowStock, isNull);
    expect(vm.data!.movements, isNull);
    expect(vm.data!.orders, isEmpty);
  });

  test('a failed summary keeps the server error whole', () async {
    final vm = await loaded(
      dashboard: FakeDashboardRepository(
        () async => throw const ApiException('The server is busy.'),
      ),
    );

    expect(vm.data, isNull);
    expect(vm.error?.message, 'The server is busy.');
  });

  test('a slow load for the previous store is dropped', () async {
    final slow = Completer<DashboardSummary>();
    var call = 0;
    final vm = HomeViewModel(
      dashboard: FakeDashboardRepository(
        () => ++call == 1 ? slow.future : Future.value(summary(totalUnits: 7)),
      ),
      inventory: FakeHomeInventoryRepository(),
      orders: FakeOrderRepository(),
      purchaseOrders: po.FakePurchaseOrderRepository(),
    );
    Future<void> load() => vm.load(
      canSeeMoney: false,
      canViewInventory: false,
      canViewOrders: false,
      canViewPurchaseOrders: false,
    );

    final first = load();
    await load();
    slow.complete(summary(totalUnits: 999));
    await first;

    expect(vm.data?.summary?.totalUnits, 7);
  });
}
