import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/features/shelves/data/shelf_models.dart';

void main() {
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
            {
              'spotId': 's1',
              'address': 'R1-S1',
              'colour': '#ff0000',
              'isShopFloor': true,
              'quantity': 3,
            },
          ],
        },
      ],
    });
    expect(w.item.label, 'Red');
    expect(w.places.single.shelves.single.quantity, 3);
    expect(w.places.single.shelves.single.isShopFloor, isTrue);
    expect(w.places.single.shelves.single.colour, 0xFFFF0000);
    expect(w.places.single.notShelved, 2);
  });
}
