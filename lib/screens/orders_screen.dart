import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../api/api_repository.dart';
import '../api/shop_context.dart';
import '../models/inventory_models.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import '../widgets/async_state.dart';
import '../widgets/ui.dart';

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
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _repo = ApiRepository();
  final _query = TextEditingController();
  final _time = DateFormat('h:mm a');
  final _day = DateFormat('EEE, d MMM');
  Timer? _debounce;

  static const _statuses = [
    'ALL',
    'DRAFT',
    'CONFIRMED',
    'PARTIALLY_DISPATCHED',
    'DISPATCHED',
    'CANCELLED',
  ];
  String _status = 'ALL';
  bool _counterOnly = false;

  List<OrderItemSummary>? _orders;
  String? _error;
  int _req = 0;
  int _seenRevision = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final revision = ShopScope.of(context).revision;
    if (revision != _seenRevision) {
      _seenRevision = revision;
      _load();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  /// Every status comes back at once so each chip can show its count; the chip filters locally.
  Future<void> _load() async {
    final id = ++_req;
    setState(() => _error = null);
    try {
      final orders = await _repo.getOrders(search: _query.text.trim());
      if (mounted && id == _req) setState(() => _orders = orders);
    } on ApiException catch (e) {
      if (mounted && id == _req) setState(() => _error = e.message);
    }
  }

  String _dayLabel(DateTime d) {
    final today = DateUtils.dateOnly(DateTime.now());
    final day = DateUtils.dateOnly(d);
    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return _day.format(d);
  }

  @override
  Widget build(BuildContext context) {
    final all = (_orders ?? const <OrderItemSummary>[])
        .where((o) => !_counterOnly || o.atCounter)
        .toList();
    final shown = all
        .where((o) => _status == 'ALL' || o.status == _status)
        .toList();
    final value = shown
        .where((o) => o.status != 'CANCELLED')
        .fold<double>(0, (a, o) => a + o.totalAmount);

    // Day headers between the cards.
    final rows = <Object>[];
    String? lastDay;
    for (final o in shown) {
      final label = _dayLabel(o.date);
      if (label != lastDay) {
        final dayOrders = shown.where(
          (x) => _dayLabel(x.date) == label && x.status != 'CANCELLED',
        );
        rows.add((
          label,
          dayOrders.fold<double>(0, (a, x) => a + x.totalAmount),
        ));
        lastDay = label;
      }
      rows.add(o);
    }

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
                            _orders == null
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
                    selected: _counterOnly,
                    onSelected: (v) => setState(() => _counterOnly = v),
                    selectedColor: AppColors.accentGoldLight,
                    checkmarkColor: AppColors.accentGold,
                    side: BorderSide(
                      color: _counterOnly
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
                onChanged: (_) {
                  setState(() {});
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 450), _load);
                },
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _statuses.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final s = _statuses[i];
                  final sel = s == _status;
                  final count = s == 'ALL'
                      ? all.length
                      : all.where((o) => o.status == s).length;
                  return Pressable(
                    onTap: () => setState(() => _status = s),
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
              child: _orders == null && _error != null
                  ? ErrorView(message: _error!, onRetry: _load)
                  : _orders == null
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
                      message: _query.text.isNotEmpty
                          ? 'No orders match "${_query.text}".'
                          : 'No orders here.',
                    )
                  : RefreshIndicator(
                      color: AppColors.accentGold,
                      onRefresh: _load,
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
      onTap: () => showOrderDetails(context, _repo, o),
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

void showOrderDetails(
  BuildContext context,
  ApiRepository repo,
  OrderItemSummary order,
) {
  final detail = repo.getOrder(order.id);
  final dateFormat = DateFormat('d MMM yyyy, h:mm a');
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.bgCard,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scroll) => FutureBuilder<OrderDetail>(
        future: detail,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const LoadingView(message: 'Loading the order…');
          }
          if (snap.hasError) return ErrorView(message: snap.error.toString());
          final d = snap.data!;
          Widget total(String label, double amount, {bool bold = false}) =>
              Padding(
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
                      amount < 0
                          ? '−${formatRupees(-amount)}'
                          : formatRupees(amount),
                      style: TextStyle(
                        fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
                        fontSize: bold ? 18 : 13,
                      ),
                    ),
                  ],
                ),
              );
          return ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
                  if (d.summary.customerPhone.isNotEmpty)
                    d.summary.customerPhone,
                ].join(' • '),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                dateFormat.format(d.summary.date),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
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
        },
      ),
    ),
  );
}
