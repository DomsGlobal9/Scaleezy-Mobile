import 'package:intl/intl.dart';

import 'package:scaleezy/core/view_model/view_model.dart';
import 'package:scaleezy/features/orders/data/order_repository.dart';
import 'package:scaleezy/features/orders/data/receipt_models.dart';

/// One printed line: text on the left, an amount on the right.
typedef ReceiptRow = ({String left, String right, bool bold, bool muted});

ReceiptRow _row(
  String left, [
  String right = '',
  bool bold = false,
  bool muted = false,
]) => (left: left, right: right, bold: bold, muted: muted);

final _amount = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '',
  decimalDigits: 2,
);

/// 2,998.00 -- a receipt always shows paise, as the web's does.
String receiptAmount(num v) => _amount.format(v).trim();

/// A counter bill laid out as the web's 80 mm receipt (Receipt.jsx), for the screen and for
/// WhatsApp. Every section is worked out here once, so the two always say the same.
class ReceiptViewModel extends ViewModel {
  ReceiptViewModel(this.orderId, [OrderRepository? repo])
    : _repo = repo ?? OrderRepository();

  final String orderId;
  final OrderRepository _repo;
  static final _when = DateFormat('d MMM yyyy, h:mm a');

  Receipt? _receipt;
  String? _error;

  /// Null while loading and after a failure.
  Receipt? get receipt => _receipt;
  String? get error => _error;

  Future<void> load() async {
    _error = null;
    notifyListeners();
    try {
      _receipt = await _repo.getReceipt(orderId);
    } catch (e) {
      if (disposed) return;
      _error = e.toString();
    }
    notifyListeners();
  }

  /// Shop name first. Opened from the order, never straight from the sale, so it is a reprint:
  /// DUPLICATE, so it cannot pass for a second purchase.
  List<String> get header {
    final r = _receipt!;
    return [
      r.shopName ?? r.storeName ?? '',
      ?r.shopAddress,
      if (r.shopPhone != null) 'Ph ${r.shopPhone}',
      if (r.gstNumber != null) 'GSTIN ${r.gstNumber}',
      'DUPLICATE',
    ];
  }

  List<ReceiptRow> get meta {
    final r = _receipt!;
    return [
      _row('Bill ${r.orderNumber}', _when.format(r.createdAt)),
      _row('Store ${r.storeName ?? ''}'),
      if (r.soldBy != null) _row('Sold by ${r.soldBy}'),
      if (r.customerName != null)
        _row('Customer ${r.customerName}', r.customerPhoneMasked ?? ''),
      if (r.hasBuyer)
        _row(
          [
            'Bill to ${r.buyerName ?? r.customerName ?? ''}',
            if (r.buyerGstin != null) ' · GSTIN ${r.buyerGstin}',
            if (r.buyerAddress != null) '\n${r.buyerAddress}',
          ].join(),
        ),
    ];
  }

  List<ReceiptRow> get lines {
    final r = _receipt!;
    return [
      for (final item in r.items) ...[
        _row(item.name),
        if (r.gst.isNotEmpty && item.taxRateBps != null)
          _row(
            [
              if (item.hsnCode != null)
                '${item.hsnCode!.startsWith('99') ? 'SAC' : 'HSN'} ${item.hsnCode} · ',
              'GST ${_rate(item.taxRateBps! / 100)}%',
            ].join(),
            '',
            false,
            true,
          ),
        _row(
          '  ${item.quantity} × ${receiptAmount(item.listUnitPrice)}',
          receiptAmount(item.listUnitPrice * item.quantity),
        ),
        for (final (title, amount) in item.discounts)
          _row('  $title', '-${receiptAmount(amount)}', false, true),
      ],
    ];
  }

  /// Totals, taxes, then how it was paid.
  List<ReceiptRow> get totals {
    final r = _receipt!;
    // With the GST breakdown, a bare "Tax" line would read as added on top of GST-inclusive prices.
    final bareTax = r.taxAmount > 0 && r.gst.isEmpty;
    final paid = r.payments.where((p) => p.kind != 'REFUND');
    final change = paid.fold<double>(0, (a, p) => a + p.changeGiven);
    return [
      if (bareTax || r.shippingAmount > 0) ...[
        _row('Items', receiptAmount(r.subtotal - r.discountAmount)),
        if (bareTax) _row('Tax', receiptAmount(r.taxAmount)),
        if (r.shippingAmount > 0)
          _row('Shipping', receiptAmount(r.shippingAmount)),
      ],
      if (r.gst.isNotEmpty) ...[
        _row(
          'Taxable value',
          receiptAmount(r.gst.fold<double>(0, (a, g) => a + g.taxable)),
        ),
        for (final g in r.gst) ...[
          if (g.cgst > 0)
            _row('CGST ${_rate(g.rateBps / 200)}%', receiptAmount(g.cgst)),
          if (g.sgst > 0)
            _row('SGST ${_rate(g.rateBps / 200)}%', receiptAmount(g.sgst)),
          if (g.igst > 0)
            _row('IGST ${_rate(g.rateBps / 100)}%', receiptAmount(g.igst)),
        ],
      ],
      if (r.roundOff != 0)
        _row(
          'Round off',
          '${r.roundOff > 0 ? '+' : '-'}${receiptAmount(r.roundOff.abs())}',
        ),
      _row('Total', '₹${receiptAmount(r.total)}', true),
      for (final p in paid)
        _row(
          [
            'Paid ${paymentMethodLabel(p.method)}',
            if ((p.cashReceived ?? 0) > 0)
              ' (got ${receiptAmount(p.cashReceived!)})',
            if (p.reference != null && p.method != 'CASH')
              ' ${p.method == 'CARD' ? '••' : ''}${p.reference}',
          ].join(),
          receiptAmount(p.amount),
        ),
      if (change > 0) _row('Change', receiptAmount(change)),
      for (final p in r.payments.where((p) => p.kind == 'REFUND'))
        _row(
          'Paid back (return) ${paymentMethodLabel(p.method)}',
          '-${receiptAmount(p.amount)}',
        ),
      if (r.writtenOff > 0) _row('Written off', receiptAmount(r.writtenOff)),
      if (r.due > 0) _row('Due', receiptAmount(r.due), true),
    ];
  }

  List<String> get footer {
    final r = _receipt!;
    return [
      if (!(r.taxAmount > 0)) 'Prices include GST.',
      ?r.receiptFooter,
      'Thank you!',
    ];
  }

  /// The customer's number for WhatsApp, or null to let WhatsApp ask who to send it to.
  String? get shareNumber => _receipt?.customerPhone;

  /// The receipt as WhatsApp text, opened by the same greeting the web's share uses.
  /// shortcut: every line is sent; a very long bill may be cut short by WhatsApp's link limit --
  /// cap the item lines if that is ever reported.
  String get shareText {
    final r = _receipt!;
    String line(ReceiptRow row) {
      final text = row.right.isEmpty ? row.left : '${row.left}  ${row.right}';
      return row.bold ? '*$text*' : text;
    }

    final head = header;
    return [
      'Hello${r.customerName == null ? '' : ' ${r.customerName}'}, your bill ${r.orderNumber} is ready.',
      '',
      '*${head.first}*',
      ...head.skip(1),
      '',
      ...meta.map(line),
      '',
      ...lines.map(line),
      '',
      ...totals.map(line),
      '',
      ...footer,
    ].join('\n');
  }

  /// 5, 2.5 -- no trailing ".0".
  static String _rate(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}
