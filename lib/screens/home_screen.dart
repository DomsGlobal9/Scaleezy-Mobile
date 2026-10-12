import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../api/api_repository.dart';
import '../api/auth_session.dart';
import '../api/shop_context.dart';
import '../models/inventory_models.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import '../widgets/async_state.dart';
import '../widgets/stock_movement_dialog.dart';
import '../widgets/ui.dart';

class HomeScreen extends StatefulWidget {
  final Function(int tabIndex)? onNavigateTab;

  const HomeScreen({super.key, this.onNavigateTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// What the home screen shows, all of it read from the server in one go.
class _HomeData {
  final DashboardSummary summary;
  final List<VariantItem> lowStock;

  /// Null when the role cannot see stock movements.
  final List<TransactionItem>? movements;

  /// Null when the role cannot see orders.
  final List<OrderItemSummary>? orders;

  const _HomeData(this.summary, this.lowStock, this.movements, this.orders);
}

class _HomeScreenState extends State<HomeScreen> {
  final _repo = ApiRepository();
  final _count = NumberFormat.decimalPattern('en_IN');

  _HomeData? _data;
  String? _error;
  int _seenRevision = -1;

  static const _movementSample = 200;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // First build, and again whenever the store picker changes.
    final revision = ShopScope.of(context).revision;
    if (revision != _seenRevision) {
      _seenRevision = revision;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _error = null);
    final session = SessionScope.read(context);
    Future<T?> optional<T>(bool allowed, Future<T> Function() call) => allowed
        ? call().then<T?>((v) => v).catchError((Object e) {
            debugPrint('Home: optional section skipped: $e');
            return null;
          })
        : Future.value(null);

    try {
      final results = await Future.wait<Object?>([
        _repo.getDashboardSummary(),
        optional(
          session.can('inventory:view'),
          () => _repo.getLowStockVariants(limit: 6),
        ),
        optional(
          session.can('inventory:view'),
          () => _repo.getTransactions(limit: _movementSample),
        ),
        optional(session.can('sales_order:view'), () => _repo.getOrders()),
      ]);
      if (!mounted) return;
      setState(
        () => _data = _HomeData(
          results[0] as DashboardSummary,
          (results[1] as List<VariantItem>?) ?? const [],
          results[2] as List<TransactionItem>?,
          results[3] as List<OrderItemSummary>?,
        ),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  // ---- Derived from real data -----------------------------------------------------------------

  List<DayFlow> _lastSevenDays(List<TransactionItem> movements) {
    final today = DateUtils.dateOnly(DateTime.now());
    return List.generate(7, (i) {
      final day = today.subtract(Duration(days: 6 - i));
      var inQty = 0, outQty = 0;
      for (final m in movements) {
        if (!DateUtils.isSameDay(m.timestamp, day)) continue;
        if (m.quantity > 0) {
          inQty += m.quantity;
        } else {
          outQty += -m.quantity;
        }
      }
      return DayFlow(day, inQty, outQty);
    });
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static String initials(String text) {
    final parts = text
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '•';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  // ---- Actions ---------------------------------------------------------------------------------

  void _showAccountSheet() {
    final session = SessionScope.read(context);
    final user = session.user;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: 18),
              Row(
                children: [
                  _Avatar(text: initials(user?.name ?? ''), size: 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? '',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          user?.email ?? '',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final r in user?.roles ?? const <String>[])
                    _Tag(text: r),
                  if ((user?.clientId ?? '').isNotEmpty)
                    _Tag(text: 'Shop: ${user!.clientId}', muted: true),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    session.logout();
                  },
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text(
                    'Sign out',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accentDanger,
                    side: BorderSide(
                      color: AppColors.accentDanger.withValues(alpha: 0.3),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _receive(VariantItem v) async {
    final done = await showStockMovement(
      context,
      variant: v,
      title: v.productTitle,
      isStockIn: true,
    );
    if (done) _load();
  }

  // ---- Build -------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accentGold,
          backgroundColor: AppColors.bgCard,
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                sliver: SliverToBoxAdapter(child: _buildHeader()),
              ),
              SliverToBoxAdapter(child: _buildLocationPicker()),
              if (data == null && _error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorView(message: _error!, onRetry: _load),
                )
              else if (data == null)
                SliverPadding(
                  padding: const EdgeInsets.all(18),
                  sliver: SliverToBoxAdapter(child: _buildSkeleton()),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 32),
                  sliver: SliverList.list(children: _buildContent(data)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final shop = ShopScope.of(context);
    final user = SessionScope.of(context).user;
    final shopName =
        shop.branding.businessName ?? user?.clientId ?? 'Your shop';
    final firstName = (user?.name ?? '').split(' ').first;

    return Row(
          children: [
            shop.branding.logoUrl != null
                ? NetImage(
                    url: shop.branding.logoUrl,
                    width: 46,
                    height: 46,
                    radius: 14,
                    fallbackIcon: Icons.storefront,
                  )
                : Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: AppColors.goldGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentGold.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initials(shopName),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    firstName.isEmpty
                        ? _greeting()
                        : '${_greeting()}, $firstName',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    shopName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            Pressable(
              onTap: _showAccountSheet,
              child: _Avatar(text: initials(user?.name ?? ''), size: 42),
            ),
          ],
        )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideX(begin: -0.04, end: 0, curve: Curves.easeOutCubic);
  }

  Widget _buildLocationPicker() {
    final shop = ShopScope.of(context);
    if (shop.locations.length < 2) {
      // One store: say which, nothing to choose.
      if (shop.locations.isEmpty) return const SizedBox(height: 12);
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
        child: Row(
          children: [
            const Icon(
              Icons.place_rounded,
              size: 14,
              color: AppColors.textMuted,
            ),
            const SizedBox(width: 4),
            Text(
              shop.locations.first.name,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final options = <StockLocation?>[null, ...shop.locations];
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final loc = options[i];
          final selected = loc?.id == shop.selectedLocation?.id;
          return Pressable(
            onTap: () => shop.selectLocation(loc),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.textPrimary : AppColors.bgCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.borderLight,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    loc == null
                        ? Icons.layers_rounded
                        : _locationIcon(loc.type),
                    size: 14,
                    color: selected
                        ? const Color(0xFFFDE68A)
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    loc?.name ?? 'All stores',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static IconData _locationIcon(String type) => switch (type) {
    'WAREHOUSE' => Icons.warehouse_rounded,
    'ONLINE' => Icons.language_rounded,
    _ => Icons.storefront_rounded,
  };

  List<Widget> _buildContent(_HomeData d) {
    var i = 0;
    final movements = d.movements ?? d.summary.recentTransactions;
    return [
      _buildHero(d).entrance(i++),
      if (d.orders != null) ...[
        const SizedBox(height: 14),
        _buildToday(d.orders!).entrance(i++),
      ],
      const SizedBox(height: 22),
      _buildQuickActions().entrance(i++),
      const SizedBox(height: 22),
      const SectionHeader(title: 'At a glance').entrance(i++),
      _buildKpiGrid(d.summary).entrance(i++),
      if (d.movements != null) ...[
        const SizedBox(height: 24),
        SectionHeader(
          title: 'Low Stock Items',
          trailing: d.summary.criticalStockItems > d.lowStock.length
              ? 'All ${d.summary.criticalStockItems}'
              : null,
          onTrailing: () => widget.onNavigateTab?.call(1),
        ).entrance(i++),
        if (d.lowStock.isEmpty)
          const _EmptyNote(
            icon: Icons.verified_rounded,
            text:
                'Nothing is running low. Every tracked piece is above its reorder level.',
          ).entrance(i++)
        else
          for (final v in d.lowStock) _buildLowStockRow(v).entrance(i++),
      ],
      const SizedBox(height: 24),
      const SectionHeader(title: 'Recent Transactions').entrance(i++),
      if (movements.isEmpty)
        const _EmptyNote(
          icon: Icons.inventory_2_outlined,
          text: 'No stock has moved yet.',
        ).entrance(i++)
      else
        for (final (n, tx) in movements.take(8).indexed)
          _buildMovementRow(
            tx,
            isLast: n == movements.take(8).length - 1,
          ).entrance(i++),
    ];
  }

  Widget _buildHero(_HomeData d) {
    final s = d.summary;
    final flow = d.movements == null ? null : _lastSevenDays(d.movements!);
    final totalIn = flow?.fold<int>(0, (a, f) => a + f.inQty) ?? 0;
    final totalOut = flow?.fold<int>(0, (a, f) => a + f.outQty) ?? 0;
    // Only 200 movements come back; if even those are all from this week, the chart is partial.
    final truncated =
        d.movements != null &&
        d.movements!.length >= _movementSample &&
        d.movements!.last.timestamp.isAfter(
          DateTime.now().subtract(const Duration(days: 7)),
        );
    final location = ShopScope.of(context).selectedLocation;

    return Container(
      padding: const EdgeInsets.all(20),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Warm glow in the corner
          Positioned(
            right: -80,
            top: -90,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accentGoldHover.withValues(alpha: 0.35),
                    AppColors.accentGoldHover.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    s.inventoryValue != null ? 'STOCK VALUE' : 'PIECES ON HAND',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      location?.name ?? 'All stores',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AnimatedCount(
                value: s.inventoryValue ?? s.totalUnits,
                format: (v) => s.inventoryValue != null
                    ? formatRupees(v)
                    : _count.format(v),
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _heroStat(s.activeProducts, 'Active Products'),
                  _heroDivider(),
                  _heroStat(s.totalUnits, 'Pieces'),
                  _heroDivider(),
                  _heroStat(
                    s.criticalStockItems,
                    'Low Stock',
                    warn: s.criticalStockItems > 0,
                  ),
                ],
              ),
              if (flow != null) ...[
                const SizedBox(height: 18),
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Text(
                      'Last 7 days',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    _legendDot(
                      const Color(0xFF34D399),
                      'In +${_count.format(totalIn)}',
                    ),
                    const SizedBox(width: 12),
                    _legendDot(
                      const Color(0xFFFDA4AF),
                      'Out −${_count.format(totalOut)}',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FlowChart(days: flow, height: 96),
                if (truncated)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'From the latest 200 movements',
                      style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                    ),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(int value, String label, {bool warn = false}) => Expanded(
    child: Column(
      children: [
        AnimatedCount(
          value: value,
          format: (v) => _count.format(v),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: warn ? const Color(0xFFFDA4AF) : Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  Widget _heroDivider() =>
      Container(width: 1, height: 26, color: Colors.white12);

  Widget _legendDot(Color color, String label) => Row(
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 5),
      Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFFCBD5E1),
        ),
      ),
    ],
  );

  Widget _buildToday(List<OrderItemSummary> orders) {
    final today = orders
        .where(
          (o) =>
              DateUtils.isSameDay(o.date, DateTime.now()) &&
              o.status != 'CANCELLED',
        )
        .toList();
    final takings = today.fold<double>(0, (a, o) => a + o.totalAmount);
    final pieces = today.fold<int>(0, (a, o) => a + o.itemCount);
    final drafts = orders.where((o) => o.status == 'DRAFT').length;

    return Pressable(
      onTap: () => widget.onNavigateTab?.call(3),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.accentSuccessLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.payments_rounded,
                color: AppColors.accentSuccess,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Today's sales",
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  AnimatedCount(
                    value: takings,
                    format: formatRupees,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    today.isEmpty
                        ? 'No orders yet today'
                        : '${today.length} ${today.length == 1 ? 'order' : 'orders'} • $pieces pcs',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (drafts > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$drafts draft${drafts == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accentWarning,
                  ),
                ),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final session = SessionScope.of(context);
    final actions = <(IconData, String, Color, Color, VoidCallback)>[
      (
        Icons.qr_code_scanner_rounded,
        'Scan tag',
        AppColors.accentGold,
        AppColors.accentGoldLight,
        () => widget.onNavigateTab?.call(2),
      ),
      if (session.can('inventory:receive'))
        (
          Icons.move_to_inbox_rounded,
          'Receive Stock',
          AppColors.accentSuccess,
          AppColors.accentSuccessLight,
          () {
            widget.onNavigateTab?.call(2);
            showMessage(
              context,
              'Scan the tag of the piece you are receiving.',
            );
          },
        ),
      (
        Icons.checkroom_rounded,
        'Products',
        AppColors.accentBlue,
        AppColors.accentBlueLight,
        () => widget.onNavigateTab?.call(1),
      ),
      if (session.can('sales_order:view'))
        (
          Icons.receipt_long_rounded,
          'Orders',
          AppColors.accentPurple,
          AppColors.accentPurpleLight,
          () => widget.onNavigateTab?.call(3),
        ),
    ];

    return Row(
      children: [
        for (final (n, a) in actions.indexed) ...[
          if (n > 0) const SizedBox(width: 10),
          Expanded(
            child: Pressable(
              onTap: a.$5,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.borderLight),
                  boxShadow: AppColors.cardShadow,
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: a.$4,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(a.$1, color: a.$3, size: 20),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      a.$2,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildKpiGrid(DashboardSummary s) {
    final tiles =
        <(IconData, String, int, String, Color, Color, VoidCallback?)>[
          (
            Icons.warning_amber_rounded,
            'Low Stock Count',
            s.criticalStockItems,
            'At or under reorder level',
            AppColors.accentDanger,
            AppColors.accentDangerLight,
            () => widget.onNavigateTab?.call(1),
          ),
          (
            Icons.local_shipping_outlined,
            'Open Purchase Orders',
            s.openPurchaseOrders,
            'Draft, sent or part received',
            AppColors.accentBlue,
            AppColors.accentBlueLight,
            null,
          ),
          (
            Icons.inventory_2_outlined,
            'Awaiting',
            s.pendingReceipts,
            'Pieces ordered, not received',
            AppColors.accentWarning,
            const Color(0xFFFFFBEB),
            null,
          ),
          (
            Icons.handshake_outlined,
            'Suppliers',
            s.totalSuppliers,
            'Active vendors',
            AppColors.accentSuccess,
            AppColors.accentSuccessLight,
            null,
          ),
        ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: [
        for (final t in tiles)
          Pressable(
            onTap: t.$7,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.borderLight),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: t.$6,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(t.$1, size: 16, color: t.$5),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        t.$2,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  AnimatedCount(
                    value: t.$3,
                    format: (v) => _count.format(v),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                      color: t.$3 > 0 ? t.$5 : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    t.$4,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLowStockRow(VariantItem v) {
    final canReceive = SessionScope.of(context).can('inventory:receive');
    final progress = v.reorderLevel > 0
        ? (v.quantity / v.reorderLevel).clamp(0.0, 1.0)
        : 0.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (_, p, _) => CircularProgressIndicator(
                      value: p,
                      strokeWidth: 4,
                      strokeCap: StrokeCap.round,
                      backgroundColor: AppColors.accentDangerLight,
                      color: AppColors.accentDanger,
                    ),
                  ),
                ),
                Text(
                  '${v.quantity}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppColors.accentDanger,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  v.productTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${v.sku} • reorder at ${v.reorderLevel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (canReceive)
            Pressable(
              onTap: () => _receive(v),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accentGoldLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.accentGoldBorder),
                ),
                child: const Text(
                  'Receive Stock',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accentGold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMovementRow(TransactionItem tx, {required bool isLast}) {
    final (color, icon) = switch (tx.type) {
      'IN' => (AppColors.accentSuccess, Icons.south_west_rounded),
      'OUT' => (AppColors.accentDanger, Icons.north_east_rounded),
      _ => (AppColors.accentPurple, Icons.tune_rounded),
    };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline rail
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 1.5, color: AppColors.borderLight),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16, top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.productTitle.isNotEmpty ? tx.productTitle : tx.sku,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      reasonLabel(tx.reason),
                      if (tx.performedBy.isNotEmpty) tx.performedBy,
                      relativeTime(tx.timestamp),
                    ].join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  tx.quantity > 0 ? '+${tx.quantity}' : '${tx.quantity}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                Text(
                  'bal ${tx.balanceAfter}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Skeleton(height: 250, radius: 24),
        SizedBox(height: 14),
        Skeleton(height: 76, radius: 20),
        SizedBox(height: 22),
        Row(
          children: [
            Expanded(child: Skeleton(height: 84, radius: 18)),
            SizedBox(width: 10),
            Expanded(child: Skeleton(height: 84, radius: 18)),
            SizedBox(width: 10),
            Expanded(child: Skeleton(height: 84, radius: 18)),
            SizedBox(width: 10),
            Expanded(child: Skeleton(height: 84, radius: 18)),
          ],
        ),
        SizedBox(height: 22),
        Skeleton(height: 16, width: 120, radius: 6),
        SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: Skeleton(height: 100, radius: 18)),
            SizedBox(width: 10),
            Expanded(child: Skeleton(height: 100, radius: 18)),
          ],
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final String text;
  final double size;
  const _Avatar({required this.text, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.textPrimary,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.accentGoldBorder, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          color: const Color(0xFFFDE68A),
          fontSize: size * 0.34,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final bool muted;
  const _Tag({required this.text, this.muted = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: muted ? AppColors.bgSurface : AppColors.accentGoldLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: muted ? AppColors.borderLight : AppColors.accentGoldBorder,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: muted ? AppColors.textSecondary : AppColors.accentGold,
        ),
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyNote({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accentSuccess, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
