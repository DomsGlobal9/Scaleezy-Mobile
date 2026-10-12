import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/utils/money.dart';
import 'package:scaleezy/features/products/data/product_models.dart';

void main() {
  test('Prisma decimals arrive as strings and keep their paise', () {
    final p = ProductItem.fromJson({
      'id': 'p1',
      'title': 'Banarasi Saree',
      'productCode': 'SE-SAREE-001',
      'category': 'WOMEN',
      'productType': 'UNSTITCHED',
      'fabric': null,
      'basePrice': '2123.50',
      'status': 'ACTIVE',
      'variantSummary': {
        'variantCount': 2,
        'totalUnits': 7,
        'lowStockVariants': 1,
      },
      'colours': [
        {
          'id': 'v1',
          'variantCode': 'V1',
          'colorName': 'Crimson',
          'size': 'Free',
          'sellingPrice': null,
          'units': 4,
        },
      ],
    });
    expect(p.basePrice, 2123.5);
    expect(p.totalUnits, 7);
    expect(p.variants.single.quantity, 4);
    expect(formatRupees(p.basePrice), '₹2,123.50');
    expect(formatRupees(2123), '₹2,123');
  });

  test('variant rows sum stock across locations and tolerate hidden cost', () {
    final v = VariantItem.fromJson({
      'id': 'v1',
      'sku': 'SKU-1',
      'barcode': '8901',
      'size': 'M',
      'colorName': 'Red',
      'hexCode': '#B91C1C',
      'reorderLevel': 5,
      'totalQuantity': 3,
      'stocks': [
        {'quantity': 2, 'reservedQty': 1},
        {'quantity': 1, 'reservedQty': 0},
      ],
      'product': {'title': 'Anarkali', 'basePrice': '4499.00'},
    });
    expect(v.quantity, 3);
    expect(v.reservedQty, 1);
    expect(v.colorHex, 0xFFB91C1C);
    expect(v.averageCost, isNull);
    expect(v.sellingPrice, 4499);
    expect(v.isLowStock, isTrue);
  });
}
