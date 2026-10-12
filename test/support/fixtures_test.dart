import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/shop/shop_repository.dart';
import 'package:scaleezy/features/customers/data/customer_repository.dart';
import 'package:scaleezy/features/dashboard/data/dashboard_repository.dart';
import 'package:scaleezy/features/day_book/data/day_book_repository.dart';
import 'package:scaleezy/features/inventory/data/inventory_repository.dart';
import 'package:scaleezy/features/orders/data/order_repository.dart';
import 'package:scaleezy/features/picking/data/picking_repository.dart';
import 'package:scaleezy/features/products/data/product_repository.dart';
import 'package:scaleezy/features/purchase_orders/data/purchase_order_repository.dart';
import 'package:scaleezy/features/shelves/data/shelf_repository.dart';
import 'package:scaleezy/features/stock_counts/data/stock_count_repository.dart';
import 'package:scaleezy/features/suppliers/data/supplier_repository.dart';
import 'package:scaleezy/features/team/data/team_repository.dart';

import 'fake_api.dart';
import 'fixtures.dart';

/// Every fixture through the repository that reads it: envelope and fields line up.
void main() {
  test('products: list, one, sizes with and without cost', () async {
    final api = FakeApi()
      ..get('/products', productListJson([productJson('p1')], total: 41))
      ..get('/products/p1', ok(productJson('p1', basePrice: '2123.50')))
      ..get('/products/p1/variants', ok([variantJson('v1')]))
      ..get('/products/p2/variants', ok([variantJson('v1', cost: false)]));
    final repo = ProductRepository(api.client);

    final page = await repo.getProducts();
    expect(
      (page.items.single.title, page.total, page.pages),
      ('Banarasi Saree', 41, 3),
    );
    expect((await repo.getProduct('p1')).basePrice, 2123.5);
    final costed = (await repo.getProductVariants('p1')).single;
    expect((costed.costPrice, costed.averageCost), (850, 841.5));
    final hidden = (await repo.getProductVariants('p2')).single;
    expect((hidden.costPrice, hidden.averageCost), (null, null));
    expect(variantJson('v1', cost: false).containsKey('costPrice'), isFalse);
  });

  test('inventory: movements and alerts', () async {
    final api = FakeApi()
      ..get(
        '/inventory/transactions',
        transactionsJson([transactionJson('t1')]),
      )
      ..get('/inventory/alerts', alertsJson([alertJson('a1', quantity: 0)]));
    final tx = (await InventoryRepository(api.client).getTransactions()).single;
    expect(
      (tx.productTitle, tx.performedBy, tx.quantity),
      ('Banarasi Saree', 'Asha', 5),
    );
    final alert = (await DashboardRepository(
      api.client,
    ).getStockAlerts()).single;
    expect((alert.productId, alert.isOutOfStock), ('p-a1', true));
  });

  test('orders: list with payment, detail, receipt', () async {
    final api = FakeApi()
      ..get('/sales-orders', [orderJson('o1')])
      ..get('/sales-orders/o1', orderDetailJson('o1'))
      ..get('/counter-sales/o1/receipt', ok(receiptJson()));
    final repo = OrderRepository(api.client);

    final o = (await repo.getOrders()).single;
    expect((o.totalAmount, o.due, o.paymentShown), (3098, 98, 'PART_PAID'));
    final d = await repo.getOrder('o1');
    expect((d.lines.single.heldQty, d.payments.single.changeGiven), (2, 2));
    expect((await repo.getReceipt('o1')).total, 3098);
  });

  test('customers, suppliers, team', () async {
    final api = FakeApi()
      ..get('/customers', ok([customerJson('c1')]))
      ..get('/suppliers', ok([supplierJson('s1')]))
      ..get('/team/members', ok([memberJson('m1')]));
    expect(
      (await CustomerRepository(api.client).customers()).single.code,
      'CUS-c1',
    );
    expect(
      (await SupplierRepository(api.client).suppliers()).single.name,
      'Weavers Co',
    );
    expect((await TeamRepository(api.client).team()).single.roles, [
      'STORE_MANAGER',
    ]);
  });

  test('purchase orders: list, one, receive', () async {
    final api = FakeApi()
      ..get('/purchase-orders', ok([purchaseOrderJson('po1')]))
      ..get(
        '/purchase-orders/po1',
        ok(purchaseOrderJson('po1', items: [poLineJson('i1', received: 4)])),
      )
      ..post('/purchase-orders/po1/receive', receiveAnswerJson());
    final repo = PurchaseOrderRepository(api.client);

    expect((await repo.purchaseOrders()).single.deliverToActive, isTrue);
    expect((await repo.purchaseOrder('po1')).lines.single.outstanding, 6);
    final received = await repo.receivePurchaseOrder(
      'po1',
      quantities: {'i1': 2},
      receivedByName: 'Asha',
      requestKey: 'k1',
    );
    expect(received, (receiptNumber: 'GRN-0007', duplicate: false));
  });

  test('shelves: tree, spot, find, waiting', () async {
    final api = FakeApi()
      ..get('/shelves/locations/:id/spots', shelfTreeJson())
      ..get('/shelves/spots/:id', spotContentsJson('r1-s1'))
      ..get('/shelves/find', findJson())
      ..get(
        '/shelves/locations/:id/not-shelved',
        notShelvedJson([notShelvedRowJson('v1')]),
      );
    final repo = ShelfRepository(api.client);

    final tree = await repo.shelfTree('loc-main');
    expect((tree.notShelved, tree.spots.single.flatten.length), (3, 3));
    expect((await repo.spot('r1-s1')).total, 2);
    expect(
      (await repo.findOnShelves(
        'saree',
      )).single.places.single.shelves.single.quantity,
      3,
    );
    expect((await repo.notShelved('loc-main')).single.notShelved, 2);
  });

  test('picking and stock counts', () async {
    final api = FakeApi()
      ..get('/shelves/pick/orders', pickOrdersJson([pickOrderJson('so1')]))
      ..get('/shelves/pick/list', pickListJson())
      ..get('/stock-counts', ok([countJson('c1')]))
      ..get('/stock-counts/c1', ok(countDetailJson()));
    final pick = PickingRepository(api.client);
    expect((await pick.pickOrders('loc-main')).single.pieces, 2);
    expect((await pick.pickList('loc-main', ['so1'])).pieces, 3);

    final counts = StockCountRepository(api.client);
    expect((await counts.stockCounts()).single.status, 'IN_PROGRESS');
    expect((await counts.stockCount('c1')).items.length, 3);
  });

  test('day book with and without cost; shop branding and stores', () async {
    final api = FakeApi()
      ..get('/daybook', ok(dayBookJson()))
      ..get('/daybook', ok(dayBookJson(cost: false)), query: {'date': 'x'})
      ..get('/branding', brandingJson())
      ..get('/locations', locationsJson());
    final days = DayBookRepository(api.client);
    expect((await days.getDay()).profit, 3167.61);
    expect((await days.getDay(date: 'x')).profit, isNull);

    final shop = ShopRepository(api.client);
    expect((await shop.getBranding()).businessName, 'Lakshmi Silks');
    final stores = await shop.getLocations();
    expect(stores.map((s) => s.code), [
      'MAIN-STORE',
      'CHIRALA',
      'ONLINE',
      'OLD',
    ]);
    expect(stores.last.active, isFalse);
  });
}
