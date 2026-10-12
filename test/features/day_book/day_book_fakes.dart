import 'package:scaleezy/features/day_book/data/day_book_models.dart';
import 'package:scaleezy/features/day_book/data/day_book_repository.dart';

import '../products/products_fakes.dart' show offlineClient;

/// The backend's COST_FIELDS (cost-visibility.middleware.ts), removed at any depth for a person
/// without cost:view, as its withoutKeys does.
const costFields = {
  'costPrice',
  'averageCost',
  'lastPurchaseCost',
  'lastCostUpdatedAt',
  'previousAverageCost',
  'newAverageCost',
  'inventoryValue',
  'totalValue',
  'unitCost',
  'totalCost',
  'grossProfit',
  'costOfGoods',
  'marginPercent',
  'profitPercent',
  'averageCostMinor',
  'unitCostMinor',
  'totalCostMinor',
};

dynamic withoutCost(dynamic v) => switch (v) {
  Map m => {
    for (final e in m.entries)
      if (!costFields.contains(e.key)) e.key: withoutCost(e.value),
  },
  List l => l.map(withoutCost).toList(),
  _ => v,
};

/// One day as daybook.service.ts build() returns it (the `data` of GET /daybook): sold 4,
/// one piece came back, cash and UPI at the counter, count balanced but value re-valued.
Map<String, dynamic> dayBookJson({
  String date = '2026-10-12',
  bool inProgress = true,
  bool cost = true,
}) {
  final j = <String, dynamic>{
    'date': date,
    'money': {
      'taken': {
        'CASH': {'amount': 4200, 'count': 3},
        'UPI': {'amount': 6830.5, 'count': 2},
        'CREDIT': {'amount': 300, 'count': 1},
      },
      'paidBack': {
        'CASH': {'amount': 1200, 'count': 1},
      },
      'cashInDrawer': 3000,
    },
    'range': null,
    'days': null,
    'timezone': 'Asia/Kolkata',
    'businessName': 'Lakshmi Silks',
    'inProgress': inProgress,
    'quiet': false,
    'opening': {
      'units': 120,
      'value': 180000,
      'source': 'derived',
      'asOf': '2026-10-11T18:30:00.000Z',
    },
    'closing': {'units': 183, 'value': 273320},
    'measuredClosing': {'units': 183, 'value': 276407.57},
    'balanced': true,
    'valueMatches': false,
    'valueGap': 3087.57,
    'measuredClosingValue': 276407.57,
    'stockIn': {
      'lines': [
        {
          'reason': 'PURCHASE_RECEIPT',
          'label': 'Purchase received',
          'units': 66,
          'value': 99000,
        },
        {
          'reason': 'CUSTOMER_RETURN',
          'label': 'Customer returns',
          'units': 1,
          'value': 1500,
        },
      ],
      'totalUnits': 67,
      'totalValue': 100500,
    },
    'stockOut': {
      'lines': [
        {
          'reason': 'SALE',
          'label': 'Sold and dispatched',
          'units': 4,
          'value': 7180,
        },
      ],
      'totalUnits': 4,
      'totalValue': 7180,
    },
    'transfers': {'unitsMoved': 0},
    'sales': {
      'dispatchCount': 2,
      'unitsDispatched': 4,
      'revenue': 11530,
      'gstCollected': 549.06,
      'returns': {
        'count': 1,
        'units': 1,
        'value': 2240,
        'gst': 106.67,
        'cost': 1500,
      },
      'netSales': 8847.61,
      'costOfGoods': 7180,
      'netCost': 5680,
      'grossProfit': 3167.61,
      'unitsSoldWithoutCost': 0,
      'orders': [
        {
          'dispatchNumber': 'DSP-0007',
          'orderNumber': 'SO-0042',
          'customer': 'Priya Sharma',
          'units': 3,
          'value': 8998,
          'status': 'DISPATCHED',
        },
        {
          'dispatchNumber': 'DSP-0008',
          'orderNumber': 'SO-0043',
          'customer': null,
          'units': 1,
          'value': 2532,
          'status': 'DISPATCHED',
        },
      ],
    },
    'byLocation': [
      {
        'locationId': 'l1',
        'name': 'Main Store',
        'code': 'MS',
        'unitsIn': 67,
        'unitsOut': 4,
        'netChange': 63,
        'transferIn': 0,
        'transferOut': 0,
        'movementCount': 5,
      },
    ],
    'topMovers': [
      {
        'sku': 'SAR-RED-M',
        'title': 'Banarasi Saree',
        'unitsOut': 3,
        'unitsIn': 0,
      },
    ],
    'adjustments': [
      {
        'sku': 'KUR-BLU-L',
        'title': 'Cotton Kurta',
        'units': -1,
        'reason': 'Manual corrections',
        'by': 'Asha',
        'at': '2026-10-12T06:00:00.000Z',
      },
    ],
    'alsoToday': {
      'purchaseOrdersRaised': 1,
      'purchaseOrdersReceived': 2,
      'newVariantsAdded': 5,
    },
  };
  return cost ? j : Map<String, dynamic>.from(withoutCost(j));
}

DayBook dayBook({
  String date = '2026-10-12',
  bool inProgress = true,
  bool cost = true,
}) => DayBook.fromJson(
  dayBookJson(date: date, inProgress: inProgress, cost: cost),
);

/// Records each (date, locationId) asked for and answers with [answer].
class FakeDayBookRepository extends DayBookRepository {
  FakeDayBookRepository(this.answer) : super(offlineClient());

  Future<DayBook> Function(String? date) answer;
  final calls = <(String?, String?)>[];

  @override
  Future<DayBook> getDay({String? date, String? locationId}) {
    calls.add((date, locationId));
    return answer(date);
  }
}
