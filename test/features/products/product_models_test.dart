import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/utils/money.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/features/products/data/product_models.dart';
import 'package:scaleezy/features/products/presentation/widgets/stock_pill.dart';

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

  test(
    '"You pay" is the hand-entered cost; the average only when it differs',
    () {
      final hidden = VariantItem.fromJson({'id': 'v1', 'averageCost': null});
      expect((hidden.costPrice, hidden.averageCostIfDifferent), (null, null));

      final same = VariantItem.fromJson({
        'id': 'v2',
        'costPrice': '900.00',
        'averageCost': '900.00',
      });
      expect((same.costPrice, same.averageCostIfDifferent), (900, null));

      final differs = VariantItem.fromJson({
        'id': 'v3',
        'costPrice': '900.00',
        'averageCost': '841.50',
      });
      expect((differs.costPrice, differs.averageCostIfDifferent), (900, 841.5));

      // /variants/search sends 0 for "not set" and for "never costed".
      final unset = VariantItem.fromSearchJson({
        'id': 'v4',
        'costPrice': 0,
        'averageCost': 0,
      });
      expect((unset.costPrice, unset.averageCostIfDifferent), (null, null));
      final averageOnly = VariantItem.fromSearchJson({
        'id': 'v5',
        'costPrice': 0,
        'averageCost': 760,
      });
      expect(averageOnly.averageCostIfDifferent, 760);
    },
  );

  test('a search hit is exact only on a code, ignoring case', () {
    final hit = SearchResults.fromJson({
      'variants': [
        {
          'id': 'v1',
          'label': 'Saree - Red - M',
          'code': 'SE-001-RED-M',
          'sku': 'SVM-46P3D3TJ',
          'barcode': '8901234',
        },
      ],
      'products': [],
    }).variants.single;
    expect(hit.exactCode('svm-46p3d3tj'), 'SVM-46P3D3TJ');
    expect(hit.exactCode(' 8901234 '), '8901234');
    expect(hit.exactCode('saree'), isNull);
  });

  test('stock words follow the website; below zero is never green', () {
    expect(stockLook(-2), (label: '-2 · oversold', tone: Tone.danger));
    expect(stockLook(-2, low: true).tone, Tone.danger);
    expect(stockLook(0), (label: 'Out of stock', tone: Tone.danger));
    expect(stockLook(3, low: true), (label: 'Low stock', tone: Tone.warning));
    expect(stockLook(12), (label: '12 in stock', tone: Tone.success));
  });
}
