import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/features/purchase_orders/data/purchase_order_models.dart';

void main() {
  test('purchase order lines know what is outstanding', () {
    final po = PurchaseOrderDetail.fromJson({
      'id': 'po1',
      'poNumber': 'PO-7',
      'status': 'PARTIALLY_RECEIVED',
      'createdAt': '2026-09-01T00:00:00Z',
      'supplier': {'name': 'Weavers Co', 'phone': '9800000000'},
      'items': [
        {
          'id': 'i1',
          'variantId': 'v1',
          'productTitle': 'Saree',
          'sku': 'S1',
          'orderedQty': 10,
          'receivedQty': 4,
          'unitPrice': '850.50',
        },
      ],
    });
    expect(po.summary.canReceive, isTrue);
    expect(po.summary.lineCount, 1);
    expect(po.lines.single.outstanding, 6);
    expect(po.lines.single.unitPrice, 850.5);
  });
}
