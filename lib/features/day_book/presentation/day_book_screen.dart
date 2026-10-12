import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:scaleezy/core/shop/shop_context.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/core/utils/money.dart';
import 'package:scaleezy/core/widgets/async_state.dart';
import 'package:scaleezy/core/widgets/ui.dart';
import 'package:scaleezy/features/day_book/data/day_book_models.dart';
import 'package:scaleezy/features/day_book/presentation/view_models/day_book_view_model.dart';
import 'package:scaleezy/features/orders/data/receipt_models.dart';

/// One business day, read only, laid out as the web's Day Book: the balance line, sales,
/// money at the counter, then what came in and went out. Follows the store chosen in the app.
class DayBookScreen extends StatefulWidget {
  /// Tests pass their own; otherwise the screen makes and owns one.
  final DayBookViewModel? viewModel;

  const DayBookScreen({super.key, this.viewModel});

  @override
  State<DayBookScreen> createState() => _DayBookScreenState();
}

class _DayBookScreenState extends State<DayBookScreen> {
  late final DayBookViewModel _vm = widget.viewModel ?? DayBookViewModel();
  final _heading = DateFormat('EEEE, d MMMM yyyy');
  final _num = NumberFormat.decimalPattern('en_IN');
  int _seenRevision = -1;

  /// The order the web lists them in.
  static const _methods = [
    'CASH',
    'UPI',
    'CARD',
    'BANK_TRANSFER',
    'CHEQUE',
    'POINTS',
    'CREDIT',
    'ONLINE',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shop = ShopScope.of(context);
    if (shop.revision != _seenRevision) {
      _seenRevision = shop.revision;
      _vm.setLocation(shop.selectedLocation?.id);
    }
  }

  @override
  void dispose() {
    if (widget.viewModel == null) _vm.dispose();
    super.dispose();
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final day = _vm.day ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: day.isAfter(now) ? now : day,
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (picked != null) _vm.showDay(picked);
  }

  @override
  Widget build(BuildContext context) {
    final store = ShopScope.of(context).selectedLocation?.name;
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => _buildScreen(store),
    );
  }

  Widget _buildScreen(String? store) {
    final book = _vm.book;
    final error = _vm.error;

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accentGold,
          onRefresh: _vm.load,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              PageHeader(title: 'Day book', subtitle: store ?? 'All stores'),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                child: _dayBar(book),
              ),
              if (book == null && error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: ErrorView(message: error, onRetry: _vm.load),
                )
              else if (book == null)
                for (final h in const [150.0, 190.0, 120.0])
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                    child: Skeleton(height: h, radius: 20),
                  )
              else
                ..._sections(book),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dayBar(DayBook? book) {
    final day = _vm.day;
    return SurfaceCard(
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous day',
            onPressed: day == null ? null : _vm.previousDay,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Pressable(
              onTap: _pickDay,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          day == null ? 'Today' : _heading.format(day),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (book?.inProgress == true) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentGoldLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'STILL RUNNING',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accentGold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Next day',
            onPressed: _vm.canGoForward ? _vm.nextDay : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }

  List<Widget> _sections(DayBook b) {
    var i = 0;
    final money = b.taken.isNotEmpty || b.paidBack.isNotEmpty;
    return [
      if (b.quiet)
        _section(
          'Nothing moved this day',
          subtitle:
              'No stock came in or went out${b.inProgress ? ' so far today' : ''}, and nothing was dispatched.',
          index: i++,
        ),
      if (b.opening != null && b.closing != null) _balance(b, i++),
      if (b.hasSales) _sales(b, i++),
      if (money)
        _section(
          'Money at the counter',
          subtitle:
              'Taken on sales and paid back on returns, by how. Points and store credit are not cash in the drawer.',
          index: i++,
          children: [
            _stat(
              'Cash in the drawer from these',
              formatRupees(b.cashInDrawer),
              color: b.cashInDrawer >= 0
                  ? AppColors.accentSuccess
                  : AppColors.accentDanger,
            ),
            const SizedBox(height: 6),
            for (final m in _methods)
              if (b.taken[m] != null || b.paidBack[m] != null)
                _line(
                  paymentMethodLabel(m),
                  b.taken[m] == null ? '—' : formatRupees(b.taken[m]!),
                  sub: b.paidBack[m] == null
                      ? null
                      : 'Paid back ${formatRupees(b.paidBack[m]!)}',
                ),
          ],
        ),
      _reasons('Stock that came in', b.cameIn, b.inLines, true, i++),
      _reasons('Stock that went out', b.wentOut, b.outLines, false, i++),
      if (b.unitsMoved > 0)
        _section(
          'Moved between your own locations',
          subtitle:
              'Your total stock does not change — it just sits somewhere else.',
          index: i++,
          children: [_line('Units moved', _num.format(b.unitsMoved))],
        ),
      if (b.byLocation.isNotEmpty)
        _section(
          'By location',
          subtitle: 'What changed where.',
          index: i++,
          children: [
            for (final l in b.byLocation)
              _line(
                l.name,
                _signed(l.netChange),
                sub: [
                  'In +${_num.format(l.unitsIn)}',
                  'Out -${_num.format(l.unitsOut)}',
                  if (l.transferIn > 0)
                    'Transferred in +${_num.format(l.transferIn)}',
                  if (l.transferOut > 0)
                    'Transferred out -${_num.format(l.transferOut)}',
                ].join(' • '),
              ),
          ],
        ),
      if (b.topMovers.isNotEmpty)
        _section(
          'Busiest items',
          index: i++,
          children: [
            for (final m in b.topMovers)
              _line(
                m.title.isEmpty ? '—' : m.title,
                '+${_num.format(m.unitsIn)}  -${_num.format(m.unitsOut)}',
                sub: m.sku.isEmpty ? null : m.sku,
              ),
          ],
        ),
      if (b.corrections.isNotEmpty)
        _section(
          'Manual corrections',
          subtitle:
              'Changes somebody made by hand, rather than from an order or a delivery.',
          index: i++,
          children: [
            for (final c in b.corrections)
              _line(
                c.item.isEmpty ? '—' : c.item,
                _signed(c.units),
                sub: [c.reason, ?c.by].join(' • '),
              ),
          ],
        ),
      _section(
        'Also on this day',
        index: i++,
        children: [
          _line('Purchase orders raised', _num.format(b.purchaseOrdersRaised)),
          _line(
            'Purchase orders received',
            _num.format(b.purchaseOrdersReceived),
          ),
          _line('New items added', _num.format(b.newItems)),
        ],
      ),
    ];
  }

  /// Opening + came in - went out = closing, and whether that was checked.
  Widget _balance(DayBook b, int index) {
    final (icon, colour, note) = switch ((b.balanced, b.valueMatches)) {
      (true, false) => (
        Icons.info_outline_rounded,
        AppColors.textSecondary,
        'Every piece is accounted for. The closing value is '
            '${formatRupees((b.valueGap ?? 0).abs())} '
            '${(b.valueGap ?? 0) > 0 ? 'lower than' : 'higher than'} what your stock is worth '
            'today (${formatRupees(b.measuredClosingValue ?? 0)}), because stock you already had '
            'was re-valued when new stock arrived at a different price. Nothing is missing.',
      ),
      (true, _) => (
        Icons.check_circle_rounded,
        AppColors.accentSuccess,
        'The books balance for this day.',
      ),
      (false, _) => (
        Icons.warning_amber_rounded,
        AppColors.accentDanger,
        'These figures do not add up — treat them as unreliable and tell support.',
      ),
      _ => (
        Icons.info_outline_rounded,
        AppColors.textMuted,
        'There is no separate record for this day to check these totals against.',
      ),
    };
    return _section(
      'Stock for the day',
      subtitle: 'Opening + came in − went out = closing',
      index: index,
      children: [
        Row(
          children: [
            Expanded(child: _figure('Opening stock', b.opening!)),
            Expanded(
              child: _figure(
                'Came in',
                b.cameIn,
                sign: '+',
                color: AppColors.accentSuccess,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _figure(
                'Went out',
                b.wentOut,
                sign: '−',
                color: AppColors.accentWarning,
              ),
            ),
            Expanded(child: _figure('Closing stock', b.closing!)),
          ],
        ),
        const Divider(height: 26),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: colour),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                note,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colour,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sales(DayBook b, int index) {
    return _section(
      'Sales dispatched',
      subtitle:
          'Counted when the goods actually left, not when the order was written.',
      index: index,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 14,
          children: [
            _stat('Dispatches', _num.format(b.dispatchCount)),
            _stat('Units sent', _num.format(b.unitsDispatched)),
            _stat('Billed', formatRupees(b.revenue)),
            if (b.gstCollected > 0)
              _stat('GST in it', formatRupees(b.gstCollected)),
            if (b.returnedValue > 0)
              _stat(
                'Returned (${_num.format(b.returnedUnits)})',
                '−${formatRupees(b.returnedValue)}',
              ),
            if (b.hasDeductions)
              _stat('Sales you keep', formatRupees(b.netSales)),
            // Cost and profit only reach people allowed to see what the shop paid.
            if (b.cost != null)
              _stat('What it cost you', formatRupees(b.cost!)),
            if (b.profit != null)
              _stat(
                'Profit',
                formatRupees(b.profit!),
                color: b.profit! >= 0
                    ? AppColors.accentSuccess
                    : AppColors.accentDanger,
              ),
          ],
        ),
        if (b.profit != null && b.hasDeductions) ...[
          const SizedBox(height: 12),
          Text(
            'Profit is worked out on ${formatRupees(b.netSales)}: what was billed'
            '${b.gstCollected > 0 ? ', less ${formatRupees(b.gstCollected)} GST that is collected for the government' : ''}'
            '${b.returnedValue > 0 ? ', less ${formatRupees(b.returnedValue - b.returnedGst)} for what came back' : ''}.',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        if (b.profit != null && b.unitsSoldWithoutCost > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accentGoldLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accentGoldBorder),
            ),
            child: Text(
              'This profit is higher than the real one. '
              '${_num.format(b.unitsSoldWithoutCost)} of the units sold had no cost recorded, '
              'so their full selling price is counted as profit. Add a cost price to those '
              'items to see the true figure.',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        if (b.dispatches.isNotEmpty) ...[
          const Divider(height: 26),
          for (final d in b.dispatches)
            _line(
              d.customer ?? '—',
              formatRupees(d.value),
              sub:
                  '${d.dispatchNumber} • ${d.orderNumber} • ${_num.format(d.units)} pcs',
            ),
        ],
      ],
    );
  }

  Widget _reasons(
    String title,
    StockFigure total,
    List<DayBookLine> lines,
    bool cameIn,
    int index,
  ) {
    final colour = cameIn ? AppColors.accentSuccess : AppColors.accentWarning;
    return _section(
      title,
      subtitle: [
        '${_num.format(total.units)} pieces',
        if (total.value != null) formatRupees(total.value!),
      ].join(' • '),
      index: index,
      children: [
        if (lines.isEmpty)
          Text(
            cameIn ? 'Nothing came in.' : 'Nothing went out.',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        for (final l in lines)
          _line(
            l.label,
            _num.format(l.units),
            sub: l.value == null ? null : formatRupees(l.value!),
            rightColor: colour,
          ),
      ],
    );
  }

  // ---- Small building blocks ------------------------------------------------------------------

  String _signed(int n) => '${n >= 0 ? '+' : ''}${_num.format(n)}';

  Widget _section(
    String title, {
    String? subtitle,
    required int index,
    List<Widget> children = const [],
  }) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
    child: SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (children.isNotEmpty) const SizedBox(height: 12),
          ...children,
        ],
      ),
    ).entrance(index),
  );

  Widget _figure(
    String label,
    StockFigure f, {
    String sign = '',
    Color color = AppColors.textPrimary,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AppColors.textMuted,
          letterSpacing: 0.5,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        '$sign${_num.format(f.units)}',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: color,
          height: 1.1,
        ),
      ),
      if (f.value != null)
        Text(
          formatRupees(f.value!),
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
    ],
  );

  Widget _stat(String label, String value, {Color? color}) => SizedBox(
    width: 136,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ],
    ),
  );

  Widget _line(String left, String right, {String? sub, Color? rightColor}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    left,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (sub != null)
                    Text(
                      sub,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: rightColor ?? AppColors.textPrimary,
              ),
            ),
          ],
        ),
      );
}
