import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/core/utils/labels.dart';
import 'package:scaleezy/core/utils/money.dart';
import 'package:scaleezy/core/widgets/async_state.dart';
import 'package:scaleezy/core/widgets/status_pill.dart';
import 'package:scaleezy/core/widgets/ui.dart';
import 'package:scaleezy/features/inventory/data/inventory_models.dart';
import 'package:scaleezy/features/inventory/presentation/widgets/stock_movement_dialog.dart';
import 'package:scaleezy/features/products/data/product_models.dart';
import 'package:scaleezy/features/products/presentation/view_models/product_detail_view_model.dart';
import 'package:scaleezy/features/products/presentation/widgets/stock_pill.dart';

const _tabular = [FontFeature.tabularFigures()];

/// One product: its photographs, every size and colour, where each piece is, and what happened
/// to it. Its back button pops `true` when stock was moved (`false` if not) so the products list
/// can refresh; a swipe back pops null.
class ProductDetailScreen extends StatefulWidget {
  final ProductItem product;

  /// Tests pass their own; otherwise the screen makes and owns one.
  final ProductDetailViewModel? viewModel;

  const ProductDetailScreen({super.key, required this.product, this.viewModel});

  static String heroTag(String productId) => 'product-photo-$productId';

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late final ProductDetailViewModel _vm =
      widget.viewModel ?? ProductDetailViewModel(widget.product);

  ProductItem get p => widget.product;

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

  Future<void> _move(VariantItem v, bool isStockIn) async {
    final done = await showStockMovement(
      context,
      variant: v,
      title: '${p.title} (${v.label})',
      isStockIn: isStockIn,
    );
    if (done) _vm.stockMoved();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => _buildScreen(),
    );
  }

  Widget _buildScreen() {
    final c = context.colors;
    final type = Theme.of(context).textTheme;
    final variants = _vm.visibleVariants;
    final colours = _vm.colours;
    final heroPhoto = _vm.heroPhoto;
    final status = describeStatus(productStatuses, p.status);
    final category = describe(const {}, p.category);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _vm.load,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 360,
              pinned: true,
              stretch: true,
              backgroundColor: c.card,
              leading: Padding(
                padding: const EdgeInsets.all(8),
                child: CircleAvatar(
                  backgroundColor: c.card.withValues(alpha: 0.92),
                  child: IconButton(
                    tooltip: 'Back',
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: c.text,
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(context).pop(_vm.changed),
                  ),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [StretchMode.zoomBackground],
                background: Hero(
                  tag: ProductDetailScreen.heroTag(p.id),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: NetImage(
                      key: ValueKey(heroPhoto),
                      url: heroPhoto,
                      width: double.infinity,
                      height: double.infinity,
                      radius: 0,
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  color: c.bg,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                transform: Matrix4.translationValues(0, -16, 0),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(p.title, style: type.headlineSmall),
                        ),
                        const SizedBox(width: 12),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            formatRupees(p.basePrice),
                            style: type.titleLarge!.copyWith(
                              fontFeatures: _tabular,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusPill(status.label, status.tone),
                        Text(
                          [
                            p.productCode,
                            if (category != '—') category,
                            if (p.fabric.isNotEmpty) p.fabric,
                          ].join(' · '),
                          style: type.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _stat('${_vm.variantCount}', 'Sizes & colours'),
                        const SizedBox(width: 10),
                        _stat('${_vm.pieces}', 'Pieces'),
                        const SizedBox(width: 10),
                        _stat(
                          '${_vm.lowOrOut}',
                          'Low / out',
                          warn: _vm.warnLow,
                        ),
                      ],
                    ),
                    if (colours.length > 1) ...[
                      const SizedBox(height: 20),
                      Text('Colours', style: type.titleSmall),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 86,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _colourChip(null, 'All', null, null),
                            for (final colour in colours)
                              _colourChip(
                                colour.$1,
                                colour.$1,
                                colour.$2,
                                colour.$3,
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
            if (_vm.variants == null && _vm.error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorView.fromError(
                  _vm.error!,
                  what: 'sizes and colours',
                  onRetry: _vm.load,
                ),
              )
            else if (_vm.variants == null)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.list(
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      const Skeleton(height: 130),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              )
            else if (variants.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  Icons.style_outlined,
                  'This product has no sizes or colours yet.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                sliver: SliverList.separated(
                  itemCount: variants.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _VariantCard(
                    key: ValueKey(variants[i].id),
                    variant: variants[i],
                    onMove: (inbound) => _move(variants[i], inbound),
                    loadHistory: () => _vm.history(variants[i].id),
                  ).entrance(i),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// A KPI tile: caps title, ~20/600 value.
  Widget _stat(String value, String label, {bool warn = false}) {
    final c = context.colors;
    final type = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: warn ? c.danger : c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: type.labelSmall,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: type.titleLarge!.copyWith(
                fontSize: 20,
                color: warn ? c.danger : c.text,
                fontFeatures: _tabular,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _colourChip(String? key, String label, String? photo, int? hex) {
    final c = context.colors;
    final type = Theme.of(context).textTheme;
    final selected = _vm.colour == key;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Pressable(
        onTap: () => _vm.selectColour(key),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? c.brandSolid : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: key == null
                      ? Container(
                          color: c.input,
                          child: Icon(
                            Icons.apps_rounded,
                            color: c.textSecondary,
                            size: 20,
                          ),
                        )
                      : photo != null
                      ? NetImage(url: photo, width: 50, height: 50, radius: 0)
                      : Container(color: hex == null ? c.input : Color(hex)),
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 60,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: type.labelMedium!.copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? c.text : c.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VariantCard extends StatefulWidget {
  final VariantItem variant;
  final void Function(bool isStockIn) onMove;
  final Future<List<TransactionItem>> Function() loadHistory;

  const _VariantCard({
    super.key,
    required this.variant,
    required this.onMove,
    required this.loadHistory,
  });

  @override
  State<_VariantCard> createState() => _VariantCardState();
}

class _VariantCardState extends State<_VariantCard> {
  bool _open = false;
  Future<List<TransactionItem>>? _history;

  VariantItem get v => widget.variant;

  void _toggle() {
    setState(() {
      _open = !_open;
      _history ??= widget.loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final type = Theme.of(context).textTheme;
    final session = SessionScope.of(context);
    final maxAtLocation = v.stockByLocation.fold<int>(
      1,
      (m, l) => l.quantity > m ? l.quantity : m,
    );
    final averageCost = v.averageCostIfDifferent;

    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (v.photoUrl != null) ...[
                NetImage(url: v.photoUrl, width: 44, height: 44, radius: 8),
                const SizedBox(width: 12),
              ] else if (v.colorHex != null) ...[
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Color(v.colorHex!),
                    shape: BoxShape.circle,
                    border: Border.all(color: c.borderFocus, width: 1.5),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v.label.isEmpty ? v.sku : v.label,
                      style: type.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [v.sku, if (v.barcode.isNotEmpty) v.barcode].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.labelMedium!.copyWith(
                        color: c.textMuted,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StockPill(v.quantity, low: v.isLowStock),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              if (v.sellingPrice != null)
                _meta('You sell at', formatRupees(v.sellingPrice!)),
              if (v.costPrice != null)
                _meta('You pay', formatRupees(v.costPrice!)),
              if (averageCost != null)
                _meta('Average cost', formatRupees(averageCost)),
              if (v.reservedQty > 0)
                _meta('Held for orders', '${v.reservedQty}'),
              if (v.reorderLevel > 0) _meta('Reorder at', '${v.reorderLevel}'),
            ],
          ),
          if (v.stockByLocation.length > 1 ||
              (v.stockByLocation.length == 1 &&
                  v.stockByLocation.first.quantity > 0)) ...[
            const SizedBox(height: 12),
            for (final l in v.stockByLocation)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 96,
                      child: Text(
                        l.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: type.labelMedium!.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(
                            begin: 0,
                            // Oversold rows draw an empty bar; the number says the rest.
                            end: (l.quantity / maxAtLocation).clamp(0, 1),
                          ),
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOutCubic,
                          builder: (_, t, _) => LinearProgressIndicator(
                            value: t,
                            minHeight: 6,
                            backgroundColor: c.input,
                            color: c.brand,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 32,
                      child: Text(
                        '${l.quantity}',
                        textAlign: TextAlign.right,
                        style: type.labelMedium!.copyWith(
                          fontWeight: FontWeight.w600,
                          color: l.quantity < 0 ? c.danger : c.text,
                          fontFeatures: _tabular,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              if (session.can('inventory:receive'))
                _action(
                  'Receive stock',
                  Icons.add_rounded,
                  c.success,
                  () => widget.onMove(true),
                ),
              if (session.can('inventory:adjust')) ...[
                const SizedBox(width: 8),
                _action(
                  'Issue stock',
                  Icons.remove_rounded,
                  c.danger,
                  () => widget.onMove(false),
                ),
              ],
              const Spacer(),
              if (session.can('inventory:view'))
                TextButton.icon(
                  onPressed: _toggle,
                  icon: AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: const Icon(Icons.expand_more_rounded, size: 18),
                  ),
                  label: const Text('History'),
                  style: TextButton.styleFrom(
                    foregroundColor: c.textSecondary,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !_open
                ? const SizedBox(width: double.infinity)
                : FutureBuilder<List<TransactionItem>>(
                    future: _history,
                    builder: (_, snap) => _historyBody(snap),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _historyBody(AsyncSnapshot<List<TransactionItem>> snap) {
    final c = context.colors;
    final type = Theme.of(context).textTheme;
    if (snap.connectionState != ConnectionState.done) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Skeleton(height: 60),
      );
    }
    if (snap.hasError) {
      final e = snap.error;
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          e is ApiException ? e.message : 'Could not load the history.',
          style: type.labelMedium!.copyWith(color: c.danger),
        ),
      );
    }
    final rows = snap.data ?? const [];
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'Nothing has moved yet.',
          style: type.labelMedium!.copyWith(color: c.textMuted),
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.input,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (final (i, t) in rows.indexed)
            Padding(
              padding: EdgeInsets.only(bottom: i == rows.length - 1 ? 0 : 10),
              child: Row(
                children: [
                  Icon(
                    t.quantity > 0
                        ? Icons.south_west_rounded
                        : Icons.north_east_rounded,
                    size: 14,
                    color: t.quantity > 0 ? c.success : c.danger,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      [
                        reasonLabel(t.reason),
                        if (t.performedBy.isNotEmpty) t.performedBy,
                        relativeTime(t.timestamp),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.labelMedium!.copyWith(
                        color: c.textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  Text(
                    '${t.quantity > 0 ? '+' : ''}${t.quantity} → ${t.balanceAfter}',
                    style: type.labelMedium!.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: _tabular,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: (30 * i).ms),
        ],
      ),
    );
  }

  Widget _meta(String label, String value) {
    final c = context.colors;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label ',
            style: TextStyle(color: c.textMuted),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: c.text,
              fontFeatures: _tabular,
            ),
          ),
        ],
      ),
      style: Theme.of(
        context,
      ).textTheme.labelMedium!.copyWith(fontWeight: FontWeight.w400),
    );
  }

  Widget _action(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) => Pressable(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tint(color, 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tint(color, 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium!.copyWith(color: color),
          ),
        ],
      ),
    ),
  );
}
