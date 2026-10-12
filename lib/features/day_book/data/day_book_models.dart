import 'package:scaleezy/core/utils/json_parse.dart';

// Shapes read from inventory_backend src/services/daybook.service.ts (build()). Money there is
// already a plain number. The route needs report:financial, which implies cost:view, so cost
// normally arrives; it is still read as optional because the server strips cost keys by name.

/// Pieces and what they are worth.
class StockFigure {
  final int units;
  final double? value;

  StockFigure.fromJson(Map<String, dynamic> j)
    : units = asInt(j['units'] ?? j['totalUnits']),
      value = asMoney(j['value'] ?? j['totalValue']);

  static StockFigure? maybe(dynamic j) =>
      j is Map ? StockFigure.fromJson(Map<String, dynamic>.from(j)) : null;
}

/// One reason stock came in or went out: "Purchase received", 66 pieces.
class DayBookLine {
  final String label;
  final int units;
  final double? value;

  DayBookLine.fromJson(Map<String, dynamic> j)
    : label = asOptString(j['label']) ?? asString(j['reason']),
      units = asInt(j['units']),
      value = asMoney(j['value']);
}

class DayBookDispatch {
  final String dispatchNumber;
  final String orderNumber;
  final String? customer;
  final int units;
  final double value;

  DayBookDispatch.fromJson(Map<String, dynamic> j)
    : dispatchNumber = asString(j['dispatchNumber']),
      orderNumber = asString(j['orderNumber']),
      customer = asOptString(j['customer']),
      units = asInt(j['units']),
      value = asMoney(j['value']) ?? 0;
}

class DayBookLocation {
  final String name;
  final int unitsIn;
  final int unitsOut;
  final int netChange;
  final int transferIn;
  final int transferOut;

  DayBookLocation.fromJson(Map<String, dynamic> j)
    : name = [
        asString(j['name']),
        if (asOptString(j['code']) != null) '(${j['code']})',
      ].join(' '),
      unitsIn = asInt(j['unitsIn']),
      unitsOut = asInt(j['unitsOut']),
      netChange = asInt(j['netChange']),
      transferIn = asInt(j['transferIn']),
      transferOut = asInt(j['transferOut']);
}

class DayBookMover {
  final String title;
  final String sku;
  final int unitsIn;
  final int unitsOut;

  DayBookMover.fromJson(Map<String, dynamic> j)
    : title = asString(j['title']),
      sku = asString(j['sku']),
      unitsIn = asInt(j['unitsIn']),
      unitsOut = asInt(j['unitsOut']);
}

/// A change somebody made by hand, and who.
class DayBookCorrection {
  final String item;
  final int units;
  final String reason;
  final String? by;

  DayBookCorrection.fromJson(Map<String, dynamic> j)
    : item = '${asString(j['title'])} ${asString(j['sku'])}'.trim(),
      units = asInt(j['units']),
      reason = asString(j['reason']),
      by = asOptString(j['by']);
}

/// One business day, as GET /daybook answers it.
class DayBook {
  /// YYYY-MM-DD in the shop's own timezone.
  final String date;

  /// Today, still running: the figures will change.
  final bool inProgress;

  /// Nothing moved and nothing was dispatched.
  final bool quiet;

  final StockFigure? opening;
  final StockFigure? closing;

  /// Null when there is no separate record to check the count against.
  final bool? balanced;
  final bool? valueMatches;
  final double? valueGap;
  final double? measuredClosingValue;

  final StockFigure cameIn;
  final StockFigure wentOut;
  final List<DayBookLine> inLines;
  final List<DayBookLine> outLines;
  final int unitsMoved;

  final int dispatchCount;
  final int unitsDispatched;

  /// Billed, GST included.
  final double revenue;
  final double gstCollected;
  final int returnCount;
  final int returnedUnits;
  final double returnedValue;
  final double returnedGst;

  /// Billed, less GST, less what came back.
  final double netSales;

  /// What the goods sold cost, less what came back on the shelf. Null without cost:view.
  final double? cost;

  /// Null without cost:view.
  final double? profit;
  final int unitsSoldWithoutCost;
  final List<DayBookDispatch> dispatches;

  /// Payment method (CASH, UPI, ...) to amount.
  final Map<String, double> taken;
  final Map<String, double> paidBack;
  final double cashInDrawer;

  final List<DayBookLocation> byLocation;
  final List<DayBookMover> topMovers;
  final List<DayBookCorrection> corrections;

  final int purchaseOrdersRaised;
  final int purchaseOrdersReceived;
  final int newItems;

  DayBook.fromJson(Map<String, dynamic> j)
    : this._(j, asMap(j['sales']), asMap(asMap(j['sales'])['returns']));

  DayBook._(
    Map<String, dynamic> j,
    Map<String, dynamic> s,
    Map<String, dynamic> r,
  ) : date = asString(j['date']),
      inProgress = j['inProgress'] == true,
      quiet = j['quiet'] == true,
      opening = StockFigure.maybe(j['opening']),
      closing = StockFigure.maybe(j['closing']),
      balanced = j['balanced'] is bool ? j['balanced'] as bool : null,
      valueMatches = j['valueMatches'] is bool
          ? j['valueMatches'] as bool
          : null,
      valueGap = asMoney(j['valueGap']),
      measuredClosingValue = asMoney(j['measuredClosingValue']),
      cameIn = StockFigure.fromJson(asMap(j['stockIn'])),
      wentOut = StockFigure.fromJson(asMap(j['stockOut'])),
      inLines = asMaps(
        asMap(j['stockIn'])['lines'],
      ).map(DayBookLine.fromJson).toList(),
      outLines = asMaps(
        asMap(j['stockOut'])['lines'],
      ).map(DayBookLine.fromJson).toList(),
      unitsMoved = asInt(asMap(j['transfers'])['unitsMoved']),
      dispatchCount = asInt(s['dispatchCount']),
      unitsDispatched = asInt(s['unitsDispatched']),
      revenue = asMoney(s['revenue']) ?? 0,
      gstCollected = asMoney(s['gstCollected']) ?? 0,
      returnCount = asInt(r['count']),
      returnedUnits = asInt(r['units']),
      returnedValue = asMoney(r['value']) ?? 0,
      returnedGst = asMoney(r['gst']) ?? 0,
      netSales = asMoney(s['netSales']) ?? 0,
      // costOfGoods is one of the server's cost keys; netCost is not, so it only counts beside it.
      cost = s.containsKey('costOfGoods')
          ? asMoney(s['netCost']) ?? asMoney(s['costOfGoods'])
          : null,
      profit = asMoney(s['grossProfit']),
      unitsSoldWithoutCost = asInt(s['unitsSoldWithoutCost']),
      dispatches = asMaps(s['orders']).map(DayBookDispatch.fromJson).toList(),
      taken = _amounts(asMap(j['money'])['taken']),
      paidBack = _amounts(asMap(j['money'])['paidBack']),
      cashInDrawer = asMoney(asMap(j['money'])['cashInDrawer']) ?? 0,
      byLocation = asMaps(
        j['byLocation'],
      ).map(DayBookLocation.fromJson).toList(),
      topMovers = asMaps(j['topMovers']).map(DayBookMover.fromJson).toList(),
      corrections = asMaps(
        j['adjustments'],
      ).map(DayBookCorrection.fromJson).toList(),
      purchaseOrdersRaised = asInt(
        asMap(j['alsoToday'])['purchaseOrdersRaised'],
      ),
      purchaseOrdersReceived = asInt(
        asMap(j['alsoToday'])['purchaseOrdersReceived'],
      ),
      newItems = asInt(asMap(j['alsoToday'])['newVariantsAdded']);

  /// `{CASH: {amount, count}}` -> `{CASH: amount}`.
  static Map<String, double> _amounts(dynamic v) => asMap(
    v,
  ).map((method, m) => MapEntry(method, asMoney(asMap(m)['amount']) ?? 0));

  /// The day as a date; [date] has no time or zone.
  DateTime get day => DateTime.tryParse(date) ?? DateTime.now();

  bool get hasSales => dispatchCount > 0 || returnCount > 0;

  /// Profit is not simply billed less cost: GST or a return came off first.
  bool get hasDeductions => gstCollected > 0 || returnedValue > 0;
}
