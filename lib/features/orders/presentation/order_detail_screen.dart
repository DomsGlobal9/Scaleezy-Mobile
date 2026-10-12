import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:scaleezy/app/app_routes.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/core/utils/money.dart';
import 'package:scaleezy/core/widgets/async_state.dart';
import 'package:scaleezy/core/widgets/ui.dart';
import 'package:scaleezy/features/orders/presentation/orders_screen.dart';
import 'package:scaleezy/features/orders/presentation/view_models/order_details_view_model.dart';

/// One order: who, when, every line and the totals, with the receipt for a counter bill.
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
      backgroundColor: AppColors.bgCard,
      body: SafeArea(
        child: Column(
          children: [
            const PageHeader(title: 'Order'),
            Expanded(
              child: ListenableBuilder(
                listenable: _vm,
                builder: (context, _) => _buildContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_vm.error != null) {
      return ErrorView(message: _vm.error!, onRetry: _vm.load);
    }
    final d = _vm.detail;
    if (d == null) {
      return const LoadingView(message: 'Loading the order…');
    }
    Widget total(String label, double amount, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
              color: bold ? null : AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            amount < 0 ? '−${formatRupees(-amount)}' : formatRupees(amount),
            style: TextStyle(
              fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
              fontSize: bold ? 18 : 13,
            ),
          ),
        ],
      ),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                d.summary.orderNumber,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            orderStatusChip(d.summary.status),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          [
            d.summary.customerName,
            if (d.summary.customerPhone.isNotEmpty) d.summary.customerPhone,
          ].join(' • '),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        Text(
          _dateFormat.format(d.summary.date),
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        // As on the web: only counter bills have a receipt. Its permission, sales_order:view,
        // is the one this order was just loaded with.
        if (d.summary.atCounter) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => AppRoutes.receipt(context, d.summary.id),
              icon: const Icon(Icons.receipt_long_rounded, size: 18),
              label: const Text('Receipt'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accentGold,
                side: const BorderSide(color: AppColors.accentGoldBorder),
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        for (final (i, l) in d.lines.indexed)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        [
                          l.sku,
                          if (l.colorName.isNotEmpty) l.colorName,
                          if (l.size.isNotEmpty) 'Size ${l.size}',
                        ].join(' • '),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '${l.quantity} × ${formatRupees(l.unitPrice)}${l.fulfilledQty > 0 ? '  •  ${l.fulfilledQty} sent' : ''}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatRupees(l.totalPrice),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ).entrance(i),
        const Divider(height: 26),
        total('Subtotal', d.subtotal),
        if (d.discountAmount > 0) total('Discount', -d.discountAmount),
        if (d.taxAmount > 0) total('Tax', d.taxAmount),
        if (d.shippingAmount > 0) total('Shipping', d.shippingAmount),
        const SizedBox(height: 4),
        total('Total', d.summary.totalAmount, bold: true),
      ],
    );
  }
}
