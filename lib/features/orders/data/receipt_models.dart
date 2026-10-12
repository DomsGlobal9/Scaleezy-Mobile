import 'package:scaleezy/core/utils/json_parse.dart';

// Shapes read from inventory_backend src/services/counter-sale/counter-sale.service.ts getSale().
// Money there is already converted to numbers; it is still read with asMoney. A receipt never
// carries what the shop paid.

/// How a bill was paid, in the web's words.
const paymentMethodLabels = {
  'CASH': 'Cash',
  'UPI': 'UPI',
  'CARD': 'Card',
  'BANK_TRANSFER': 'Bank transfer',
  'CHEQUE': 'Cheque',
  'POINTS': 'Loyalty points',
  'CREDIT': 'Store credit',
  'ONLINE': 'Online (Razorpay)',
};

String paymentMethodLabel(String method) =>
    paymentMethodLabels[method] ?? method;

class ReceiptLine {
  final String name;
  final int quantity;
  final double listUnitPrice;
  final String? hsnCode;

  /// GST rate in basis points (500 = 5%); null when none was charged.
  final int? taxRateBps;

  /// Offers on this line: (title, amount).
  final List<(String, double)> discounts;

  ReceiptLine.fromJson(Map<String, dynamic> j)
    : name = [
        asString(j['title']),
        ?asOptString(j['colorName']),
        ?asOptString(j['size']),
      ].where((s) => s.isNotEmpty).join(', '),
      quantity = asInt(j['quantity']),
      listUnitPrice = asMoney(j['listUnitPrice']) ?? 0,
      hsnCode = asOptString(j['hsnCode']),
      taxRateBps = j['taxRateBps'] == null ? null : asInt(j['taxRateBps']),
      discounts = asMaps(j['discounts'])
          .map((d) => (asString(d['title']), asMoney(d['amount']) ?? 0))
          .where((d) => d.$2 > 0)
          .toList();
}

/// GST charged at one rate, added up over the lines.
class ReceiptGst {
  final int rateBps;
  final double taxable;
  final double cgst;
  final double sgst;
  final double igst;

  ReceiptGst.fromJson(Map<String, dynamic> j)
    : rateBps = asInt(j['rateBps']),
      taxable = asMoney(j['taxable']) ?? 0,
      cgst = asMoney(j['cgst']) ?? 0,
      sgst = asMoney(j['sgst']) ?? 0,
      igst = asMoney(j['igst']) ?? 0;
}

class ReceiptPayment {
  /// PAYMENT or REFUND.
  final String kind;
  final String method;
  final double amount;
  final double? cashReceived;
  final double changeGiven;
  final String? reference;

  ReceiptPayment.fromJson(Map<String, dynamic> j)
    : kind = asString(j['kind']),
      method = asString(j['method']),
      amount = asMoney(j['amount']) ?? 0,
      cashReceived = asMoney(j['cashReceived']),
      changeGiven = asMoney(j['changeGiven']) ?? 0,
      reference = asOptString(j['reference']);
}

/// One bill as GET /counter-sales/:orderId/receipt answers it.
class Receipt {
  final String id;
  final String orderNumber;

  /// Only a bill made at Inventory's own counter has a receipt; the POS till prints its own.
  final bool atCounter;
  final DateTime createdAt;
  final String? soldBy;
  final String? storeName;
  final String? customerName;

  /// Full number, e.g. "+91 98480 22338", for sending; [customerPhoneMasked] is for the paper.
  final String? customerPhone;
  final String? customerPhoneMasked;

  /// "Bill to" on a B2B invoice; null on most bills.
  final String? buyerName;
  final String? buyerGstin;
  final String? buyerAddress;
  final bool hasBuyer;

  final List<ReceiptLine> items;
  final double subtotal;
  final double discountAmount;
  final double taxAmount;
  final double shippingAmount;
  final double roundOff;

  /// What the customer pays, round-off included.
  final double total;
  final List<ReceiptPayment> payments;
  final double due;
  final double writtenOff;
  final List<ReceiptGst> gst;

  final String? shopName;
  final String? logoUrl;
  final String? shopAddress;
  final String? shopPhone;
  final String? gstNumber;
  final String? receiptFooter;

  Receipt.fromJson(Map<String, dynamic> j)
    : this._(
        j,
        asMap(j['customer']),
        asMap(j['buyer']),
        asMap(j['shop']),
        asMap(j['payment']),
      );

  Receipt._(
    Map<String, dynamic> j,
    Map<String, dynamic> customer,
    Map<String, dynamic> buyer,
    Map<String, dynamic> shop,
    Map<String, dynamic> payment,
  ) : id = asString(j['id']),
      orderNumber = asString(j['orderNumber']),
      atCounter = j['atCounter'] == true,
      createdAt = asDateOrNow(j['createdAt']),
      soldBy = asOptString(j['soldBy']),
      storeName = asOptString(asMap(j['store'])['name']),
      customerName = asOptString(customer['name']),
      customerPhone = asOptString(customer['phone']),
      customerPhoneMasked = asOptString(customer['phoneMasked']),
      buyerName = asOptString(buyer['name']),
      buyerGstin = asOptString(buyer['gstin']),
      buyerAddress = asOptString(buyer['address']),
      hasBuyer = buyer.isNotEmpty,
      items = asMaps(j['items']).map(ReceiptLine.fromJson).toList(),
      subtotal = asMoney(j['subtotal']) ?? 0,
      discountAmount = asMoney(j['discountAmount']) ?? 0,
      taxAmount = asMoney(j['taxAmount']) ?? 0,
      shippingAmount = asMoney(j['shippingAmount']) ?? 0,
      roundOff = asMoney(j['roundOff']) ?? 0,
      total = asMoney(j['total']) ?? 0,
      payments = asMaps(j['payments']).map(ReceiptPayment.fromJson).toList(),
      due = asMoney(payment['due']) ?? 0,
      writtenOff = asMoney(payment['writtenOff']) ?? 0,
      gst = asMaps(j['gst']).map(ReceiptGst.fromJson).toList(),
      shopName = asOptString(shop['name']),
      logoUrl = asOptString(shop['logoUrl']),
      shopAddress = asOptString(shop['address']),
      shopPhone = asOptString(shop['phone']),
      gstNumber = asOptString(shop['gstNumber']),
      receiptFooter = asOptString(shop['receiptFooter']);
}
