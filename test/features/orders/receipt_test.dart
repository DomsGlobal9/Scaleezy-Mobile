import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/features/orders/data/receipt_models.dart';
import 'package:scaleezy/features/orders/presentation/receipt_screen.dart';
import 'package:scaleezy/features/orders/presentation/view_models/receipt_view_model.dart';

import 'orders_fakes.dart';

Future<ReceiptViewModel> _loaded(Map<String, dynamic> json) async {
  final vm = ReceiptViewModel(
    'o1',
    FakeOrderRepository(receipt: (_) async => Receipt.fromJson(json)),
  );
  await vm.load();
  return vm;
}

String _text(ReceiptRow r) =>
    r.right.isEmpty ? r.left : '${r.left} | ${r.right}';

void main() {
  test('receipt model reads a counter bill', () {
    final r = Receipt.fromJson(receiptJson());
    expect(r.orderNumber, 'SO-0042');
    expect(r.atCounter, isTrue);
    expect(r.storeName, 'Main Store');
    expect(r.customerPhone, '+91 98480 22338');
    expect(r.customerPhoneMasked, '••••2338');
    expect(r.hasBuyer, isFalse);
    expect(r.items.first.name, 'Banarasi Saree, Red, Free');
    expect(r.items.first.discounts, [('Festive 5%', 149.9)]);
    expect(r.items.last.name, 'Stitching');
    expect(r.items.last.taxRateBps, 1800);
    expect(r.gst.map((g) => g.rateBps), [500, 1800]);
    expect(r.total, 3098);
    expect(r.roundOff, -0.1);
    expect(r.due, 98);
    expect(r.payments.last.reference, 'UTR123');
    expect(r.payments.last.changeGiven, 0);
    expect(r.shopName, 'Lakshmi Silks');
    expect(r.gstNumber, '37ABCDE1234F1Z5');
  });

  test('receipt model tolerates decimals as strings and a B2B buyer', () {
    final r = Receipt.fromJson({
      ...receiptJson(),
      'total': '3098.00',
      'buyer': {'name': 'Ravi Traders', 'gstin': '37XYZ', 'address': null},
    });
    expect(r.total, 3098);
    expect(r.hasBuyer, isTrue);
    expect(r.buyerGstin, '37XYZ');
  });

  test('receipt view model lays the bill out as the web does', () async {
    final vm = await _loaded(receiptJson());

    expect(vm.header, [
      'Lakshmi Silks',
      '12 MG Road, Vijayawada',
      'Ph +91 86600 12345',
      'GSTIN 37ABCDE1234F1Z5',
      'DUPLICATE',
    ]);
    expect(vm.meta.first.left, 'Bill SO-0042');
    expect(vm.meta.first.right, contains('Oct 2026'));
    expect(vm.meta.map(_text).skip(1), [
      'Store Main Store',
      'Sold by Asha',
      'Customer Priya Sharma | ••••2338',
    ]);
    expect(vm.lines.map(_text), [
      'Banarasi Saree, Red, Free',
      'HSN 5007 · GST 5%',
      '  2 × 1,499.00 | 2,998.00',
      '  Festive 5% | -149.90',
      'Stitching',
      'SAC 998821 · GST 18%',
      '  1 × 250.00 | 250.00',
    ]);
    expect(vm.totals.map(_text), [
      'Taxable value | 2,924.34',
      'CGST 2.5% | 67.81',
      'SGST 2.5% | 67.81',
      'CGST 9% | 19.07',
      'SGST 9% | 19.07',
      'Round off | -0.10',
      'Total | ₹3,098.00',
      'Paid Cash (got 2,000.00) | 2,000.00',
      'Paid UPI UTR123 | 1,000.00',
      'Due | 98.00',
    ]);
    expect(vm.totals.where((r) => r.bold).map((r) => r.left), ['Total', 'Due']);
    expect(vm.footer, [
      'Prices include GST.',
      'No exchange without bill.',
      'Thank you!',
    ]);
  });

  test('receipt share text greets the customer and carries the bill', () async {
    final vm = await _loaded(receiptJson());
    final text = vm.shareText;

    expect(vm.shareNumber, '+91 98480 22338');
    expect(
      text,
      startsWith('Hello Priya Sharma, your bill SO-0042 is ready.\n\n'),
    );
    expect(text, contains('*Lakshmi Silks*'));
    expect(text, contains('Banarasi Saree, Red, Free'));
    expect(text, contains('  Festive 5%  -149.90'));
    expect(text, contains('*Total  ₹3,098.00*'));
    expect(text, contains('Paid UPI UTR123  1,000.00'));
    expect(text, contains('*Due  98.00*'));
    expect(text, endsWith('Thank you!'));

    final noPhone = await _loaded(receiptJson(phone: null));
    expect(noPhone.shareNumber, isNull);
  });

  test('receipt view model says why it could not load', () async {
    final vm = ReceiptViewModel(
      'o1',
      FakeOrderRepository(
        receipt: (_) async =>
            throw const ApiException('Order not found', statusCode: 404),
      ),
    );
    await vm.load();
    expect(vm.receipt, isNull);
    expect(vm.error, 'Order not found');
  });

  testWidgets('receipt screen shows the paper and a WhatsApp share', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final vm = ReceiptViewModel(
      'o1',
      FakeOrderRepository(
        receipt: (_) async => Receipt.fromJson(receiptJson()),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ReceiptScreen(orderId: 'o1', viewModel: vm),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Receipt'), findsOneWidget);
    expect(find.text('Lakshmi Silks'), findsOneWidget);
    expect(find.text('DUPLICATE'), findsOneWidget);
    expect(find.text('Banarasi Saree, Red, Free'), findsOneWidget);
    expect(find.text('₹3,098.00'), findsOneWidget);
    expect(find.text('Thank you!'), findsOneWidget);
    expect(find.text('Share on WhatsApp'), findsOneWidget);
  });

  testWidgets('a bill not made at the counter has no receipt here', (
    tester,
  ) async {
    final vm = ReceiptViewModel(
      'o1',
      FakeOrderRepository(
        receipt: (_) async => Receipt.fromJson(receiptJson(atCounter: false)),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ReceiptScreen(orderId: 'o1', viewModel: vm),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('was not sold there'), findsOneWidget);
    expect(find.text('Share on WhatsApp'), findsNothing);
    expect(find.text('DUPLICATE'), findsNothing);
  });
}
