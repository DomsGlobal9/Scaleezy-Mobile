import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/api/api_client.dart';
import 'package:scaleezy/api/auth_session.dart';
import 'package:scaleezy/models/inventory_models.dart';
import 'package:scaleezy/models/module_models.dart';
import 'package:scaleezy/screens/login_screen.dart';
import 'package:scaleezy/utils/money.dart';

void main() {
  testWidgets('login screen renders and validates empty fields', (
    tester,
  ) async {
    final session = AuthSession(ApiClient.withDio(Dio()));
    await tester.pumpWidget(
      MaterialApp(
        home: SessionScope(session: session, child: const LoginScreen()),
      ),
    );

    await tester.pumpAndSettle(); // let the entrance animation finish
    expect(find.text('Sign in to ScaleEzy'), findsOneWidget);
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
  });

  group('parsing server shapes', () {
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

    test(
      'variant rows sum stock across locations and tolerate hidden cost',
      () {
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
      },
    );

    test('permissions: owner wildcard and explicit grants', () {
      final owner = AuthUser.fromJson({
        'id': 'u',
        'email': 'a@b.c',
        'roles': ['Owner'],
        'permissions': ['*'],
      });
      final clerk = AuthUser.fromJson({
        'id': 'u',
        'email': 'a@b.c',
        'roles': [],
        'permissions': ['sales_order:view'],
      }, clientId: 'sphl');
      expect(owner.can('sales_order:create'), isTrue);
      expect(clerk.can('sales_order:view'), isTrue);
      expect(clerk.can('sales_order:create'), isFalse);
      expect(clerk.clientId, 'sphl');
    });

    test('orders list: raw array item', () {
      final o = OrderItemSummary.fromJson({
        'id': 'o1',
        'orderNumber': 'SO-0001',
        'status': 'CONFIRMED',
        'total': '8998.00',
        'customerName': null,
        'customer': {'name': 'Priya', 'phone': '9876543210'},
        'items': [
          {'quantity': 2},
          {'quantity': 1},
        ],
        'createdAt': '2026-09-30T10:00:00.000Z',
      });
      expect(o.customerName, 'Priya');
      expect(o.itemCount, 3);
      expect(o.totalAmount, 8998);
    });
  });

  group('module shapes', () {
    test('shelf tree nests racks and sums pieces', () {
      final t = ShelfTree.fromJson({
        'location': {'id': 'L1', 'name': 'Main store'},
        'count': 3,
        'pieces': {'total': 10, 'onShelves': 7, 'notShelved': 3},
        'spots': [
          {
            'id': 'r1',
            'kind': 'RACK',
            'code': 'R1',
            'address': 'R1',
            'pieces': 0,
            'branchPieces': 7,
            'children': [
              {
                'id': 's1',
                'parentId': 'r1',
                'kind': 'SHELF',
                'code': 'S1',
                'address': 'R1-S1',
                'pieces': 4,
                'children': [],
              },
              {
                'id': 's2',
                'parentId': 'r1',
                'kind': 'SHELF',
                'code': 'S2',
                'address': 'R1-S2',
                'pieces': 3,
                'children': [],
              },
            ],
          },
        ],
      });
      expect(t.notShelved, 3);
      expect(t.spots.single.holdsStock, isFalse);
      expect(
        t.spots.single.flatten.where((s) => s.holdsStock).map((s) => s.address),
        ['R1-S1', 'R1-S2'],
      );
    });

    test('where-is lists shelves per location', () {
      final w = WhereItem.fromJson({
        'variantId': 'v1',
        'productId': 'p1',
        'title': 'Saree',
        'sku': 'SKU-1',
        'colorName': 'Red',
        'size': null,
        'places': [
          {
            'locationId': 'L1',
            'location': 'Main',
            'total': 5,
            'held': 1,
            'usesShelves': true,
            'notShelved': 2,
            'shelves': [
              {'spotId': 's1', 'address': 'R1-S1', 'quantity': 3},
            ],
          },
        ],
      });
      expect(w.item.label, 'Red');
      expect(w.places.single.shelves.single.quantity, 3);
      expect(w.places.single.notShelved, 2);
    });

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

    test('team member roles flatten', () {
      final m = TeamMember.fromJson({
        'id': 'u1',
        'name': 'Asha',
        'email': 'a@b.c',
        'status': 'ACTIVE',
        'roles': [
          {
            'role': {'id': 'r', 'name': 'Manager'},
          },
        ],
      });
      expect(m.roles, ['Manager']);
    });
  });
}
