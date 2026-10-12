import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:scaleezy/app/app_routes.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/core/utils/money.dart';
import 'package:scaleezy/core/widgets/async_state.dart';
import 'package:scaleezy/core/widgets/ui.dart';
import 'package:scaleezy/features/orders/data/order_models.dart';
import 'package:scaleezy/features/orders/data/receipt_models.dart';
import 'package:scaleezy/features/orders/presentation/orders_screen.dart';
import 'package:scaleezy/features/orders/presentation/view_models/order_details_view_model.dart';

/// One order, laid out as the website's order page: who and when, the lines, the summary and the
/// payments, with the receipt for a counter bill. Read only.
class OrderDetailScreen extends StatefulWidget {
  final String orderId;

  /// Tests pass their own; otherwise the screen makes and owns one.
  final OrderDetailsViewModel? viewModel;

  const OrderDetailScreen({super.key, required this.orderId, this.viewModel});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late final OrderDetailsViewModel _vm =
      widget.viewModel ?? OrderDetailsViewModel(widget.orderId);
  final _dateFormat = DateFormat('d MMM yyyy, h:mm a');
  final _paidAt = DateFormat('d MMM, h:mm a');

  @override
  void initState() {
    super.initState();
    _vm.load();
  }

  @override
  void dispose() {
    if (widget.viewModel == null) _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _vm,
          builder: (context, _) {
            final d = _vm.detail;
            return Column(
              children: [
                PageHeader(
                  title: d == null ? 'Order' : 'Order ${d.summary.orderNumber}',
                ),
                Expanded(child: _buildContent()),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent() {
    final error = _vm.error;
    if (error != null) {
      return ErrorView.fromError(error, what: 'the order', onRetry: _vm.load);
    }
    final d = _vm.detail;
    if (d == null) {
      return const LoadingView(message: 'Loading the order…');
    }
    final o = d.summary;
    final c = context.colors;
    final type = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: orderStatusPill(o.status, large: true),
        ),
        const SizedBox(height: 8),
        Text(
          [
            'Customer: ${o.customerName}',
            if (o.customerPhone.isNotEmpty) o.customerPhone,
            'Created: ${_dateFormat.format(o.date)}',
            if (o.atCounter) 'Sold at the counter',
            ?o.locationName,
            if (o.createdByName != null) 'By ${o.createdByName}',
          ].join(' · '),
          style: type.bodyMedium!.copyWith(color: c.textSecondary),
        ),
        // As on the web: only counter bills have a receipt. Its permission, sales_order:view,
        // is the one this order was just loaded with.
        if (o.atCounter) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => AppRoutes.receipt(context, o.id),
              icon: const Icon(Icons.receipt_long_rounded, size: 18),
              label: const Text('Receipt'),
            ),
          ),
        ],
        const SizedBox(height: 16),
        _lines(d),
        const SizedBox(height: 16),
        _summary(d),
        if (o.atCounter || d.payments.isNotEmpty || o.writtenOff > 0) ...[
          const SizedBox(height: 16),
          _payments(d),
        ],
      ],
    );
  }

  Widget _card(String title, List<Widget> children, {Widget? trailing}) {
    final type = Theme.of(context).textTheme;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: type.titleMedium)),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _lines(OrderDetail d) {
    final c = context.colors;
    final type = Theme.of(context).textTheme;
    final sent = d.summary.status != 'DRAFT';
    return _card('Line items', [
      if (d.lines.isEmpty) Text('No items added yet.', style: type.bodySmall),
      for (final (i, l) in d.lines.indexed)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: i == 0 ? null : Border(top: BorderSide(color: c.border)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.title, style: type.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      [
                        l.sku,
                        if (l.colorName.isNotEmpty) l.colorName,
                        if (l.size.isNotEmpty) 'Size ${l.size}',
                      ].join(' · '),
                      style: type.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        style: type.labelMedium!.copyWith(color: c.textMuted),
                        children: [
                          TextSpan(
                            text:
                                '${l.quantity} × ${formatRupees(l.unitPrice)}',
                          ),
                          // The website's RESERVED and DISPATCHED columns.
                          if (sent && l.heldQty > 0)
                            TextSpan(
                              text: ' · ${l.heldQty} held',
                              style: TextStyle(color: c.warning),
                            ),
                          if (sent && l.fulfilledQty > 0)
                            TextSpan(
                              text: ' · ${l.fulfilledQty} sent',
                              style: TextStyle(color: c.success),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(formatRupees(l.totalPrice), style: type.titleSmall),
            ],
          ),
        ).entrance(i),
    ]);
  }

  Widget _summary(OrderDetail d) {
    final c = context.colors;
    final type = Theme.of(context).textTheme;
    Widget row(String label, String amount) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: type.bodyMedium!.copyWith(color: c.textSecondary),
            ),
          ),
          Text(
            amount,
            style: type.bodyMedium!.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
    final count = d.lines.length;
    return _card('Summary', [
      row(
        'Subtotal ($count ${count == 1 ? 'item' : 'items'})',
        formatRupees(d.subtotal),
      ),
      row('Discount', '-${formatRupees(d.discountAmount)}'),
      // "Included", not "+": these prices already contain the tax.
      row(
        'Tax${d.taxAmount > 0 ? ' (included)' : ''}',
        formatRupees(d.taxAmount),
      ),
      row('Shipping', '+${formatRupees(d.shippingAmount)}'),
      Container(
        padding: const EdgeInsets.only(top: 12),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: c.border)),
        ),
        child: Row(
          children: [
            Expanded(child: Text('Grand total', style: type.titleLarge)),
            Text(formatRupees(d.summary.totalAmount), style: type.titleLarge),
          ],
        ),
      ),
    ]);
  }

  Widget _payments(OrderDetail d) {
    final c = context.colors;
    final type = Theme.of(context).textTheme;
    final o = d.summary;
    final (label, colour) = o.due > 0
        ? ('${formatRupees(o.due)} due', c.warning)
        : o.paymentStatus == 'REFUNDED'
        ? ('Refunded', c.neutral)
        : o.paymentStatus == 'WRITTEN_OFF'
        ? ('Written off', c.danger)
        : ('Paid', c.success);
    Widget row(String title, String sub, String amount, {Color? colour}) =>
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: c.border)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: type.labelLarge!.copyWith(color: colour),
                    ),
                    if (sub.isNotEmpty)
                      Text(
                        sub,
                        style: type.labelMedium!.copyWith(color: c.textMuted),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(amount, style: type.titleSmall!.copyWith(color: colour)),
            ],
          ),
        );
    return _card(
      'Payments',
      trailing: Text(label, style: type.labelLarge!.copyWith(color: colour)),
      [
        // Udhaar written off at the POS till: not money, so it is not a payment row.
        if (o.writtenOff > 0)
          row(
            'Written off',
            'On the POS till, no money received',
            formatRupees(o.writtenOff),
            colour: c.danger,
          ),
        if (d.payments.isEmpty)
          Text('No payment recorded.', style: type.bodySmall),
        for (final p in d.payments)
          row(
            [
              if (p.kind == 'REFUND') 'Refund · ',
              paymentMethodLabel(p.method),
              if (p.reference != null) ' · ${p.reference}',
            ].join(),
            [
              _paidAt.format(p.receivedAt),
              ?p.receivedBy,
              if (p.changeGiven > 0)
                'got ${formatRupees(p.cashReceived ?? 0)}, gave back ${formatRupees(p.changeGiven)}',
            ].join(' · '),
            '${p.kind == 'REFUND' ? '-' : ''}${formatRupees(p.amount)}',
          ),
      ],
    );
  }
}
