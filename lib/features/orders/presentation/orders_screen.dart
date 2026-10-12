import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:scaleezy/app/app_routes.dart';
import 'package:scaleezy/core/shop/shop_context.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/core/utils/money.dart';
import 'package:scaleezy/core/widgets/async_state.dart';
import 'package:scaleezy/core/widgets/ui.dart';
import 'package:scaleezy/features/orders/data/order_models.dart';
import 'package:scaleezy/features/orders/presentation/view_models/orders_view_model.dart';

(Color, Color) orderStatusColours(String status) => switch (status) {
  'CONFIRMED' => (AppColors.accentBlue, AppColors.accentBlueLight),
  'DISPATCHED' => (AppColors.accentSuccess, AppColors.accentSuccessLight),
  'PARTIALLY_DISPATCHED' => (
    AppColors.accentPurple,
    AppColors.accentPurpleLight,
  ),
  'CANCELLED' => (AppColors.accentDanger, AppColors.accentDangerLight),
  'DRAFT' => (AppColors.accentWarning, const Color(0xFFFFFBEB)),
  _ => (AppColors.textSecondary, AppColors.bgSurface),
};

Widget orderStatusChip(String status) {
  final (fg, bg) = orderStatusColours(status);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      status.replaceAll('_', ' '),
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: fg),
    ),
  );
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
    final rows = _vm.rows;

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Orders',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.7,
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Text(
                            _vm.orders == null
                                ? 'Loading…'
                                : '${shown.length} orders • ${formatRupees(value)}',
                            key: ValueKey('${shown.length}-$value'),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilterChip(
                    label: const Text('Counter'),
                    selected: _vm.counterOnly,
                    onSelected: _vm.setCounterOnly,
                    selectedColor: AppColors.accentGoldLight,
                    checkmarkColor: AppColors.accentGold,
                    side: BorderSide(
                      color: _vm.counterOnly
                          ? AppColors.accentGoldBorder
                          : AppColors.borderLight,
                    ),
                    labelStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: SearchField(
                controller: _query,
                hint: 'Order no., customer name or phone',
                onChanged: _vm.search,
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: OrdersViewModel.statuses.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final s = OrdersViewModel.statuses[i];
                  final sel = s == _vm.status;
                  final count = _vm.countFor(s);
                  return Pressable(
                    onTap: () => _vm.selectStatus(s),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: sel ? AppColors.textPrimary : AppColors.bgCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: sel
                              ? AppColors.textPrimary
                              : AppColors.borderLight,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            s == 'ALL'
                                ? 'All'
                                : s.replaceAll('_', ' ').toLowerCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: sel
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: sel ? Colors.white24 : AppColors.bgSurface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: sel
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _vm.orders == null && _vm.error != null
                  ? ErrorView(message: _vm.error!, onRetry: _vm.load)
                  : _vm.orders == null
                  ? ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        for (var i = 0; i < 5; i++)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: Skeleton(height: 96, radius: 18),
                          ),
                      ],
                    )
                  : shown.isEmpty
                  ? ErrorView(
                      message: _vm.query.isNotEmpty
                          ? 'No orders match "${_vm.query}".'
                          : 'No orders here.',
                    )
                  : RefreshIndicator(
                      color: AppColors.accentGold,
                      onRefresh: _vm.load,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                        itemCount: rows.length,
                        itemBuilder: (_, i) {
                          final r = rows[i];
                          if (r is (String, double)) {
                            return Padding(
                              padding: EdgeInsets.fromLTRB(
                                4,
                                i == 0 ? 0 : 14,
                                4,
                                8,
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    r.$1,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    formatRupees(r.$2),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _card(
                              r as OrderItemSummary,
                            ).entrance(i % 15),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(OrderItemSummary o) {
    final cancelled = o.status == 'CANCELLED';
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      onTap: () => AppRoutes.orderDetail(context, o.id),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: orderStatusColours(o.status).$2,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              initialsOf(o.customerName),
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: orderStatusColours(o.status).$1,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        o.customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (o.atCounter) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.storefront_rounded,
                        size: 13,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${o.orderNumber} • ${o.itemCount} pcs • ${_time.format(o.date)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatRupees(o.totalAmount),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: cancelled
                      ? AppColors.textMuted
                      : AppColors.textPrimary,
                  decoration: cancelled ? TextDecoration.lineThrough : null,
                ),
              ),
              const SizedBox(height: 4),
              orderStatusChip(o.status),
            ],
          ),
        ],
      ),
    );
  }
}
