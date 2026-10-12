import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:scaleezy/app/app_routes.dart';
import 'package:scaleezy/core/shop/shop_context.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/core/utils/labels.dart';
import 'package:scaleezy/core/utils/money.dart';
import 'package:scaleezy/core/widgets/async_state.dart';
import 'package:scaleezy/core/widgets/status_pill.dart';
import 'package:scaleezy/core/widgets/ui.dart';
import 'package:scaleezy/features/orders/data/order_models.dart';
import 'package:scaleezy/features/orders/presentation/view_models/orders_view_model.dart';

/// The order's status in the website's words and colour.
Widget orderStatusPill(String status, {bool large = false}) {
  final look = describeStatus(orderStatuses, status);
  return StatusPill(look.label, look.tone, large: large);
}

/// Paid, "₹X due", Refunded or Written off, as the website's payment pill; null when the order
/// takes no money here or at the POS till.
Widget? orderPaymentPill(OrderItemSummary o) {
  final state = o.paymentShown;
  if (state == null) return null;
  if (state == 'PART_PAID' || state == 'UNPAID') {
    return StatusPill('${formatRupees(o.due)} due', Tone.warning);
  }
  final look = paymentStatuses[state];
  return look == null ? null : StatusPill(look.label, look.tone);
}

class OrdersScreen extends StatefulWidget {
  /// Tests pass their own; otherwise the screen makes and owns one.
  final OrdersViewModel? viewModel;

  const OrdersScreen({super.key, this.viewModel});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late final OrdersViewModel _vm = widget.viewModel ?? OrdersViewModel();
  final _query = TextEditingController();
  final _time = DateFormat('h:mm a');
  int _seenRevision = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final revision = ShopScope.of(context).revision;
    if (revision != _seenRevision) {
      _seenRevision = revision;
      _vm.load();
    }
  }

  @override
  void dispose() {
    if (widget.viewModel == null) _vm.dispose();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => _buildScreen(),
    );
  }

  Widget _buildScreen() {
    final shown = _vm.shown;
    final value = _vm.value;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(
              title: 'Orders',
              subtitle: _vm.orders == null
                  ? 'Loading…'
                  : '${shown.length} orders · ${formatRupees(value)}',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: SearchField(
                      controller: _query,
                      hint: 'Order number, phone or name',
                      onChanged: _vm.search,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _whereFrom(),
                ],
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: OrdersViewModel.statuses.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => _statusChip(OrdersViewModel.statuses[i]),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _list(shown)),
          ],
        ),
      ),
    );
  }

  /// The website's "Where from" box, as a menu beside the search.
  Widget _whereFrom() {
    final c = context.colors;
    final chosen = _vm.source.isNotEmpty;
    return PopupMenuButton<String>(
      tooltip: 'Where from',
      useRootNavigator: true,
      initialValue: _vm.source,
      onSelected: _vm.setSource,
      itemBuilder: (_) => [
        for (final e in OrdersViewModel.sources.entries)
          PopupMenuItem(value: e.key, child: Text(e.value)),
      ],
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: chosen ? c.text : c.input,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.storefront_outlined,
              size: 18,
              color: chosen ? c.card : c.textSecondary,
            ),
            if (chosen) ...[
              const SizedBox(width: 6),
              Text(
                OrdersViewModel.sources[_vm.source]!,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge!.copyWith(color: c.card),
              ),
            ],
            Icon(
              Icons.arrow_drop_down_rounded,
              color: chosen ? c.card : c.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String s) {
    final c = context.colors;
    final selected = s == _vm.status;
    final type = Theme.of(context).textTheme;
    return ChoiceChip(
      showCheckmark: false,
      selected: selected,
      onSelected: (_) => _vm.selectStatus(s),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(s == 'ALL' ? 'All' : describe(orderStatuses, s)),
          const SizedBox(width: 6),
          Text(
            '${_vm.countFor(s)}',
            style: type.labelMedium!.copyWith(
              color: selected ? c.card : c.textSecondary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(List<OrderItemSummary> shown) {
    final error = _vm.error;
    if (_vm.orders == null && error != null) {
      return ErrorView.fromError(error, what: 'orders', onRetry: _vm.load);
    }
    if (_vm.orders == null) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (var i = 0; i < 5; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Skeleton(height: 88, radius: 12),
            ),
        ],
      );
    }
    if (shown.isEmpty) {
      return const EmptyState(Icons.receipt_long_outlined, 'No orders found.');
    }
    final rows = _vm.rows;
    final type = Theme.of(context).textTheme;
    return RefreshIndicator(
      onRefresh: _vm.load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        itemCount: rows.length,
        itemBuilder: (_, i) {
          final r = rows[i];
          if (r is (String, double)) {
            return Padding(
              padding: EdgeInsets.fromLTRB(4, i == 0 ? 0 : 14, 4, 8),
              child: Row(
                children: [
                  Text(r.$1.toUpperCase(), style: type.labelSmall),
                  const Spacer(),
                  Text(formatRupees(r.$2), style: type.labelSmall),
                ],
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _row(r as OrderItemSummary).entrance(i % 15),
          );
        },
      ),
    );
  }

  /// The website's phone row: number and total, who · when · where from · by, then the pills.
  Widget _row(OrderItemSummary o) {
    final c = context.colors;
    final type = Theme.of(context).textTheme;
    final cancelled = o.status == 'CANCELLED';
    final payment = orderPaymentPill(o);
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      onTap: () => AppRoutes.orderDetail(context, o.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(o.orderNumber, style: type.titleSmall)),
              const SizedBox(width: 8),
              Text(
                formatRupees(o.totalAmount),
                style: type.titleSmall!.copyWith(
                  color: cancelled ? c.textMuted : null,
                  decoration: cancelled ? TextDecoration.lineThrough : null,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              o.customerName,
              _time.format(o.date),
              '${o.itemCount} ${o.itemCount == 1 ? 'piece' : 'pieces'}',
              o.whereFrom,
              ?o.createdByName,
            ].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: type.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [orderStatusPill(o.status), ?payment],
          ),
        ],
      ),
    );
  }
}
