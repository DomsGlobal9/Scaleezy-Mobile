import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:scaleezy/app/app_routes.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/shop/shop_context.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/core/utils/labels.dart';
import 'package:scaleezy/core/utils/money.dart';
import 'package:scaleezy/core/widgets/async_state.dart';
import 'package:scaleezy/core/widgets/status_pill.dart';
import 'package:scaleezy/core/widgets/ui.dart';
import 'package:scaleezy/features/dashboard/data/dashboard_models.dart';
import 'package:scaleezy/features/dashboard/presentation/view_models/home_view_model.dart';
import 'package:scaleezy/features/inventory/data/inventory_models.dart';
import 'package:scaleezy/features/inventory/presentation/widgets/stock_movement_dialog.dart';
import 'package:scaleezy/features/products/data/product_models.dart';

class HomeScreen extends StatefulWidget {
  final Function(int tabIndex)? onNavigateTab;

  /// Tests pass their own; otherwise the screen makes and owns one.
  final HomeViewModel? viewModel;

  const HomeScreen({super.key, this.onNavigateTab, this.viewModel});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeViewModel _vm = widget.viewModel ?? HomeViewModel();
  final _count = NumberFormat.decimalPattern('en_IN');
  int _seenRevision = -1;

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

  @override
  void dispose() {
    if (widget.viewModel == null) _vm.dispose();
    super.dispose();
  }

  Future<void> _load() {
    final session = SessionScope.read(context);
    return _vm.load(
      canSeeMoney: session.can('report:financial'),
      canViewInventory: session.can('inventory:view'),
      canViewOrders: session.can('sales_order:view'),
      canViewPurchaseOrders: session.can('purchase_order:view'),
    );
  }

  // ---- Actions ---------------------------------------------------------------------------------

  void _showAccountSheet() {
    final session = SessionScope.read(context);
    final user = session.user;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (ctx) {
        final c = ctx.colors;
        final type = Theme.of(ctx).textTheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Avatar(text: initialsOf(user?.name ?? ''), size: 52),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user?.name ?? '', style: type.titleMedium),
                          Text(user?.email ?? '', style: type.bodySmall),
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
                    if (user != null) _Tag(text: roleLabel(user)),
                    if ((user?.clientId ?? '').isNotEmpty)
                      _Tag(text: 'Shop: ${user!.clientId}', muted: true),
                  ],
                ),
                const SizedBox(height: 18),
                // No confirmation, as everywhere else (and on the website).
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      session.logout();
                    },
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Sign out'),
                    style: OutlinedButton.styleFrom(foregroundColor: c.danger),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _receive(StockAlert a) async {
    final done = await showStockMovement(
      context,
      variant: VariantItem(
        id: a.variantId,
        productTitle: a.productTitle,
        sku: a.sku,
        barcode: '',
        size: '',
        colorName: '',
        quantity: a.quantity,
        reorderLevel: a.reorderLevel,
      ),
      title: a.productTitle,
      isStockIn: true,
    );
    if (done) _load();
  }

  /// The website's LowStockWidget opens the product the alert is about.
  Future<void> _openProduct(String productId) async {
    final changed = await AppRoutes.productById(context, productId);
    // Null after a swipe back, when nobody knows: reload unless it said nothing changed.
    if (changed != false && mounted) _load();
  }

  // ---- Build -------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => _buildScreen(),
    );
  }

  Widget _buildScreen() {
    final data = _vm.data;
    final error = _vm.error;
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverToBoxAdapter(child: _buildHeader()),
              ),
              SliverToBoxAdapter(child: _buildLocationPicker()),
              if (data == null && error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorView.fromError(
                    error,
                    what: 'the dashboard',
                    onRetry: _load,
                  ),
                )
              else if (data == null)
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverToBoxAdapter(child: _buildSkeleton()),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  sliver: SliverList.list(children: _buildContent(data)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final user = SessionScope.of(context).user;
    final type = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dashboard', style: type.headlineSmall),
              const SizedBox(height: 2),
              Text(
                'Overview of your operations and analytics.',
                style: type.bodyMedium!.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Semantics(
          button: true,
          label: 'Your account',
          child: Pressable(
            onTap: _showAccountSheet,
            child: _Avatar(text: initialsOf(user?.name ?? ''), size: 40),
          ),
        ),
      ],
    );
  }

  /// The one store the app works in. No "All stores": as on the website, stock in and out
  /// always lands in a store, so the numbers here are always that store's.
  Widget _buildLocationPicker() {
    final shop = ShopScope.of(context);
    final c = context.colors;
    final type = Theme.of(context).textTheme;
    if (shop.locations.length < 2) {
      // One store: say which, nothing to choose.
      if (shop.locations.isEmpty) return const SizedBox(height: 12);
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          children: [
            Icon(Icons.place_rounded, size: 14, color: c.textMuted),
            const SizedBox(width: 4),
            Text(
              shop.locations.first.name,
              style: type.labelMedium!.copyWith(color: c.textSecondary),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        itemCount: shop.locations.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final loc = shop.locations[i];
          final selected = loc.id == shop.selectedLocation?.id;
          final fg = selected ? c.card : c.textSecondary;
          return Pressable(
            onTap: () => shop.selectLocation(loc),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? c.text : c.input,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: selected ? c.text : c.border),
              ),
              child: Row(
                children: [
                  Icon(_locationIcon(loc.type), size: 14, color: fg),
                  const SizedBox(width: 6),
                  Text(
                    loc.name,
                    style: type.labelMedium!.copyWith(
                      color: fg,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
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

  List<Widget> _buildContent(HomeData d) {
    var i = 0;
    final movements = _vm.recentMovements.take(HomeViewModel.recentCount);
    final lowStock = d.lowStock;
    return [
      _buildTiles().entrance(i++),
      if (d.orders != null) ...[
        const SizedBox(height: 12),
        _buildToday().entrance(i++),
      ],
      const SizedBox(height: 20),
      _buildQuickActions().entrance(i++),
      // A list that could not load says nothing, rather than "all fine" (as the website).
      if (lowStock != null) ...[
        const SizedBox(height: 24),
        SectionHeader(
          title: 'Low Stock Items',
          trailing: lowStock.isEmpty ? null : 'View all',
          onTrailing: () => widget.onNavigateTab?.call(1),
        ).entrance(i++),
        if (lowStock.isEmpty)
          const SurfaceCard(
            child: EmptyState(
              Icons.inventory_2_outlined,
              'No low-stock alerts right now.',
            ),
          ).entrance(i++)
        else
          for (final a in lowStock) _buildLowStockRow(a).entrance(i++),
      ],
      const SizedBox(height: 24),
      const SectionHeader(title: 'Recent Transactions').entrance(i++),
      if (movements.isEmpty)
        const SurfaceCard(
          child: EmptyState(Icons.history_rounded, 'No recent activity.'),
        ).entrance(i++)
      else
        for (final tx in movements) _buildMovementRow(tx).entrance(i++),
    ];
  }

  /// The figures, two to a row (the website's grid on a phone).
  Widget _buildTiles() {
    final store = ShopScope.of(context).selectedLocation?.name;
    final tiles = _vm.tiles(store: store);
    return Column(
      children: [
        for (var r = 0; r < tiles.length; r += 2) ...[
          if (r > 0) const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _tile(tiles[r])),
                const SizedBox(width: 10),
                Expanded(
                  child: r + 1 < tiles.length
                      ? _tile(tiles[r + 1])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _tile(HomeTile t) {
    final canPos = SessionScope.of(context).can('purchase_order:view');
    void products() => widget.onNavigateTab?.call(1);
    void openPos() => AppRoutes.purchaseOrders(context, filter: 'open');
    final (icon, tone, onTap) = switch (t.id) {
      'value' => (Icons.currency_rupee_rounded, Tone.info, products),
      'openPoValue' || 'openPos' => (
        Icons.description_outlined,
        Tone.gold,
        canPos ? openPos : null,
      ),
      'lowStock' => (
        Icons.warning_amber_rounded,
        t.alert ? Tone.danger : Tone.neutral,
        products,
      ),
      'deadStock' => (
        Icons.inventory_2_outlined,
        t.alert ? Tone.warning : Tone.neutral,
        products,
      ),
      'activeProducts' => (Icons.checkroom_rounded, Tone.success, products),
      'pieces' => (Icons.layers_outlined, Tone.info, products),
      'onOrder' => (
        Icons.local_shipping_outlined,
        t.alert ? Tone.warning : Tone.neutral,
        canPos ? openPos : null,
      ),
      _ => (Icons.handshake_outlined, Tone.purple, null),
    };
    return _KpiTile(tile: t, icon: icon, tone: tone, onTap: onTap);
  }

  Widget _buildToday() {
    final c = context.colors;
    final type = Theme.of(context).textTheme;
    final today = _vm.todayOrders;
    final pieces = _vm.todayPieces;
    final drafts = _vm.drafts;

    return SurfaceCard(
      onTap: () => widget.onNavigateTab?.call(3),
      child: Row(
        children: [
          _IconTile(icon: Icons.payments_rounded, color: c.success, size: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Today's sales", style: type.bodySmall),
                AnimatedCount(
                  value: _vm.todayTakings,
                  format: formatRupees,
                  style: type.titleLarge!.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  today.isEmpty
                      ? 'No orders yet today'
                      : '${today.length} ${today.length == 1 ? 'order' : 'orders'} · '
                            '$pieces ${pieces == 1 ? 'piece' : 'pieces'}',
                  style: type.labelMedium!.copyWith(color: c.textMuted),
                ),
              ],
            ),
          ),
          if (drafts > 0)
            StatusPill('$drafts draft${drafts == 1 ? '' : 's'}', Tone.warning),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: c.textMuted),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final c = context.colors;
    final session = SessionScope.of(context);
    final actions = <(IconData, String, Color, VoidCallback)>[
      (
        Icons.qr_code_scanner_rounded,
        'Scan tag',
        c.brandInk,
        () => widget.onNavigateTab?.call(2),
      ),
      if (session.can('inventory:receive'))
        (
          Icons.move_to_inbox_rounded,
          'Stock in',
          c.success,
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
        c.info,
        () => widget.onNavigateTab?.call(1),
      ),
      if (session.can('sales_order:view'))
        (
          Icons.receipt_long_rounded,
          'Orders',
          c.purple,
          () => widget.onNavigateTab?.call(3),
        ),
    ];

    return Row(
      children: [
        for (final (n, a) in actions.indexed) ...[
          if (n > 0) const SizedBox(width: 10),
          Expanded(
            child: SurfaceCard(
              onTap: a.$4,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
              child: Column(
                children: [
                  _IconTile(icon: a.$1, color: a.$3, size: 36),
                  const SizedBox(height: 8),
                  Text(
                    a.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// The website's low-stock row: out of stock tinted red, "on hand / reorder level", and a
  /// way to receive more for people who may.
  Widget _buildLowStockRow(StockAlert a) {
    final c = context.colors;
    final type = Theme.of(context).textTheme;
    final canReceive = SessionScope.of(context).can('inventory:receive');
    final out = a.isOutOfStock;
    final look = describeStatus(
      stockStates,
      out ? 'OUT_OF_STOCK' : 'LOW_STOCK',
    );
    final productId = a.productId;
    final row = Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: out ? tint(c.danger, 0.05) : c.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: out ? tint(c.danger, 0.2) : c.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.productTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  a.sku,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${a.quantity} / ${a.reorderLevel}',
                style: type.titleSmall!.copyWith(
                  color: out ? c.danger : c.gold,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 4),
              StatusPill(look.label, look.tone),
            ],
          ),
          if (canReceive) ...[
            const SizedBox(width: 8),
            IconButton.outlined(
              onPressed: () => _receive(a),
              tooltip: 'Receive stock',
              icon: const Icon(Icons.add_rounded, size: 18),
            ),
          ],
        ],
      ),
    );
    return productId == null
        ? row
        : Pressable(onTap: () => _openProduct(productId), child: row);
  }

  /// The website's recent-activity row.
  Widget _buildMovementRow(TransactionItem tx) {
    final c = context.colors;
    final type = Theme.of(context).textTheme;
    final (color, icon) = switch (tx.type) {
      'IN' => (c.success, Icons.south_west_rounded),
      'OUT' => (c.danger, Icons.north_east_rounded),
      _ => (c.purple, Icons.tune_rounded),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          _IconTile(icon: icon, color: color, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.productTitle.isNotEmpty ? tx.productTitle : tx.sku,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    reasonLabel(tx.reason),
                    if (tx.performedBy.isNotEmpty) tx.performedBy,
                    relativeTime(tx.timestamp),
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                tx.quantity > 0 ? '+${tx.quantity}' : '${tx.quantity}',
                style: type.titleSmall!.copyWith(
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                'bal ${_count.format(tx.balanceAfter)}',
                style: type.labelMedium!.copyWith(color: c.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    Widget pair(double h) => Row(
      children: [
        Expanded(child: Skeleton(height: h)),
        const SizedBox(width: 10),
        Expanded(child: Skeleton(height: h)),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        pair(104),
        const SizedBox(height: 10),
        pair(104),
        const SizedBox(height: 10),
        pair(104),
        const SizedBox(height: 20),
        const Skeleton(height: 84),
        const SizedBox(height: 24),
        const Skeleton(height: 16, width: 120, radius: 6),
        const SizedBox(height: 10),
        const Skeleton(height: 64),
      ],
    );
  }
}

/// A KPI card as the website's SummaryCard: caps title, the figure, then up to two notes
/// (a caveat in muted text, a second fact in secondary), with the icon in its tone.
class _KpiTile extends StatelessWidget {
  final HomeTile tile;
  final IconData icon;
  final Tone tone;
  final VoidCallback? onTap;

  const _KpiTile({
    required this.tile,
    required this.icon,
    required this.tone,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final type = Theme.of(context).textTheme;
    return Semantics(
      button: onTap != null,
      child: SurfaceCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    tile.title.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: type.labelSmall,
                  ),
                ),
                const SizedBox(width: 6),
                _IconTile(icon: icon, color: c.tone(tone), size: 32),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                tile.value,
                style: type.titleLarge!.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            if (tile.note != null) ...[
              const SizedBox(height: 4),
              Text(
                tile.note!,
                style: type.labelMedium!.copyWith(color: c.textMuted),
              ),
            ],
            if (tile.secondaryNote != null) ...[
              const SizedBox(height: 4),
              Text(
                tile.secondaryNote!,
                style: type.labelMedium!.copyWith(color: c.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// An icon on its colour at 12%, radius 8.
class _IconTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const _IconTile({
    required this.icon,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint(color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: size / 2, color: color),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String text;
  final double size;
  const _Avatar({required this.text, required this.size});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final type = Theme.of(context).textTheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint(c.brand, 0.16),
        shape: BoxShape.circle,
        border: Border.all(color: c.border),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: (size > 44 ? type.titleLarge : type.titleSmall)!.copyWith(
          color: c.brandInk,
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
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: muted ? c.input : tint(c.brand, 0.16),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.border),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium!.copyWith(
          color: muted ? c.textSecondary : c.brandInk,
        ),
      ),
    );
  }
}
