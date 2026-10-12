import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/features/picking/data/picking_models.dart';

void main() {
  test('an order waiting to be picked, as /shelves/pick/orders sends it', () {
    final o = PickOrder.fromJson({
      'id': 'so1',
      'orderNumber': 'SO-0042',
      'channel': 'POS',
      'source': null,
      'handover': 'KEEP_FOR_CUSTOMER',
      'status': 'PARTIALLY_DISPATCHED',
      'createdAt': '2026-10-10T05:30:00.000Z',
      'customer': 'Asha',
      'lines': 2,
      'pieces': 3,
    });

    expect(o.orderNumber, 'SO-0042');
    expect(o.channelName, 'Kept for customer');
    expect(o.partlySent, isTrue);
    expect(o.createdAt.toUtc(), DateTime.utc(2026, 10, 10, 5, 30));
    expect((o.lines, o.pieces), (2, 3));

    // Shopify wins over the channel; an unknown channel is shown in lower case.
    expect(
      PickOrder.fromJson({
        'channel': 'ONLINE',
        'source': 'SHOPIFY',
      }).channelName,
      'Shopify',
    );
    expect(PickOrder.fromJson({'channel': 'ONLINE'}).channelName, 'Online');
    expect(PickOrder.fromJson({'channel': 'POS'}).channelName, 'Counter');
    expect(PickOrder.fromJson({'channel': 'WHATSAPP'}).channelName, 'whatsapp');
    expect(PickOrder.fromJson({'customer': null}).customer, isNull);
  });

  test('a pick list, as /shelves/pick/list sends it', () {
    Map<String, dynamic> line(String id, int qty, {String v = 'v1'}) => {
      'orderId': 'so1',
      'orderNumber': 'SO-0042',
      'salesOrderItemId': id,
      'variantId': v,
      'quantity': qty,
      'item': {
        'variantId': v,
        'title': 'Banarasi silk',
        'sku': 'BAN-RED-M',
        'code': 'V0042',
        'barcode': '8901234',
        'colorName': 'Red',
        'hexCode': '#B91C1C',
        'size': 'M',
        'imageUrl': null,
      },
    };
    final l = PickList.fromJson({
      'location': {'id': 'L1', 'name': 'Main store'},
      'orders': [
        {
          'id': 'so1',
          'orderNumber': 'SO-0042',
          'customer': 'Asha',
          'channel': 'POS',
        },
        {
          'id': 'so2',
          'orderNumber': 'SO-0043',
          'customer': null,
          'channel': 'ONLINE',
        },
      ],
      'stops': [
        {
          'spotId': 'sp1',
          'address': 'R1-S2',
          'name': 'Silk top',
          'colour': '#22C55E',
          'isShopFloor': true,
          'labelCode': 'K7Q2M9XA',
          'picks': [line('i1', 2)],
        },
        {
          'spotId': 'sp2',
          'address': 'B-1',
          'name': null,
          'colour': 'teal',
          'isShopFloor': false,
          'labelCode': null,
          'picks': [line('i1', 1)],
        },
      ],
      'notShelved': [line('i2', 1, v: 'v2')],
      'short': [line('i3', 4, v: 'v3')],
      'pieces': 8,
    });

    expect(l.orders, {'so1': 'SO-0042', 'so2': 'SO-0043'});
    expect(l.stops.map((s) => s.address), ['R1-S2', 'B-1']);
    final first = l.stops.first;
    expect(first.colour, 0xFF22C55E);
    expect(first.isShopFloor, isTrue);
    expect(first.labelCode, 'K7Q2M9XA');
    // A colour that is not hex is simply not shown.
    expect(l.stops.last.colour, isNull);
    expect(l.stops.last.name, isNull);

    final p = first.picks.single;
    expect((p.orderId, p.salesOrderItemId, p.quantity), ('so1', 'i1', 2));
    expect(p.item.detail, 'Red · Size M · BAN-RED-M');
    expect(p.item.matches(' 8901234 '), isTrue);
    expect(p.item.matches('ban-red-m'), isTrue);
    expect(p.item.matches('v0042'), isTrue);
    expect(p.item.matches('8901'), isFalse);
    expect(l.notShelved.single.item.variantId, 'v2');
    expect(l.short.single.quantity, 4);
    expect(l.pieces, 8);
  });

  test('a free size is not called "Size Free"', () {
    final item = PickItem.fromJson({'sku': 'DUP-1', 'size': 'Free'});
    expect(item.detail, 'Free · DUP-1');
  });

  test('a dispatch line names its shelves only when there are some', () {
    expect(
      const DispatchLine(
        salesOrderItemId: 'i1',
        quantity: 3,
        fromSpots: {'sp1': 2},
      ).toJson(),
      {
        'salesOrderItemId': 'i1',
        'quantity': 3,
        'fromSpots': [
          {'spotId': 'sp1', 'quantity': 2},
        ],
      },
    );
    expect(const DispatchLine(salesOrderItemId: 'i2', quantity: 1).toJson(), {
      'salesOrderItemId': 'i2',
      'quantity': 1,
    });
  });
}
