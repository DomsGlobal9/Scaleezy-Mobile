import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/core/utils/money.dart';
import 'package:scaleezy/core/widgets/async_state.dart';
import 'package:scaleezy/core/widgets/ui.dart';
import 'package:scaleezy/features/inventory/data/inventory_models.dart';
import 'package:scaleezy/features/inventory/presentation/widgets/stock_movement_dialog.dart';
import 'package:scaleezy/features/products/data/product_models.dart';
import 'package:scaleezy/features/products/presentation/view_models/product_detail_view_model.dart';

/// One product: its photographs, every size and colour, where each piece is, and what happened
/// to it. Pops `true` when stock was moved so the products list can refresh.
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
    final variants = _vm.visibleVariants;
    final colours = _vm.colours;
    final heroPhoto = _vm.heroPhoto;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_vm.changed);
      },
      child: Scaffold(
        backgroundColor: AppColors.bgLight,
        body: RefreshIndicator(
          color: AppColors.accentGold,
          onRefresh: _vm.load,
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 360,
                pinned: true,
                stretch: true,
                backgroundColor: AppColors.bgCard,
                surfaceTintColor: Colors.transparent,
                leading: Padding(
                  padding: const EdgeInsets.all(8),
                  child: CircleAvatar(
                    backgroundColor: Colors.white.withValues(alpha: 0.92),
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: AppColors.textPrimary,
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
                  decoration: const BoxDecoration(
                    color: AppColors.bgLight,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  transform: Matrix4.translationValues(0, -24, 0),
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final t in [
                            p.category,
                            p.productType.replaceAll('_', ' '),
                            if (p.fabric.isNotEmpty) p.fabric,
                          ])
                            if (t.isNotEmpty) _pill(t),
                          if (p.status != 'ACTIVE') _pill(p.status, warn: true),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              p.title,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.6,
                                height: 1.15,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            formatRupees(p.basePrice),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: AppColors.accentGold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p.productCode,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          fontFamily: 'monospace',
                        ),
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
                        const Text(
                          'Colours',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 86,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              _colourChip(null, 'All', null, null),
                              for (final c in colours)
                                _colourChip(c.$1, c.$1, c.$2, c.$3),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ),
              if (_vm.variants == null && _vm.error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorView(message: _vm.error!, onRetry: _vm.load),
                )
              else if (_vm.variants == null)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.list(
                    children: [
                      for (var i = 0; i < 3; i++) ...[
                        const Skeleton(height: 130, radius: 20),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                )
              else if (variants.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorView(
                    message: 'This product has no sizes or colours yet.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
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
      ),
    );
  }

  Widget _pill(String text, {bool warn = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: warn ? const Color(0xFFFFFBEB) : AppColors.accentGoldLight,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: warn
            ? AppColors.accentWarning.withValues(alpha: 0.3)
            : AppColors.accentGoldBorder,
      ),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: warn ? AppColors.accentWarning : AppColors.accentGold,
      ),
    ),
  );

  Widget _stat(String value, String label, {bool warn = false}) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: warn ? AppColors.accentDanger : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _colourChip(String? key, String label, String? photo, int? hex) {
    final selected = _vm.colour == key;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Pressable(
        onTap: () => _vm.selectColour(key),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.accentGold : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: key == null
                      ? Container(
                          color: AppColors.bgSurface,
                          child: const Icon(
                            Icons.apps_rounded,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                        )
                      : photo != null
                      ? NetImage(url: photo, width: 50, height: 50, radius: 0)
                      : Container(color: Color(hex ?? 0xFFE2E8F0)),
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
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected
                      ? AppColors.accentGold
                      : AppColors.textSecondary,
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
    final session = SessionScope.of(context);
    final stockColor = v.isOutOfStock
        ? AppColors.accentDanger
        : v.isLowStock
        ? AppColors.accentWarning
        : AppColors.accentSuccess;
    final maxAtLocation = v.stockByLocation.fold<int>(
      1,
      (m, l) => l.quantity > m ? l.quantity : m,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (v.photoUrl != null) ...[
                NetImage(url: v.photoUrl, width: 44, height: 44, radius: 12),
                const SizedBox(width: 12),
              ] else if (v.colorHex != null) ...[
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Color(v.colorHex!),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black12, width: 1.5),
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
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [v.sku, if (v.barcode.isNotEmpty) v.barcode].join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                    '${v.quantity}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: stockColor,
                      height: 1,
                    ),
                  ),
                  Text(
                    v.isOutOfStock
                        ? 'sold out'
                        : (v.isLowStock ? 'running low' : 'in stock'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: stockColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              if (v.sellingPrice != null)
                _meta('You sell at', formatRupees(v.sellingPrice!)),
              if (v.averageCost != null)
                _meta('You pay', formatRupees(v.averageCost!)),
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
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(
                            begin: 0,
                            end: l.quantity / maxAtLocation,
                          ),
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOutCubic,
                          builder: (_, t, _) => LinearProgressIndicator(
                            value: t,
                            minHeight: 6,
                            backgroundColor: AppColors.bgSurface,
                            color: AppColors.accentGold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 28,
                      child: Text(
                        '${l.quantity}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
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
                  'Receive Stock',
                  Icons.add_rounded,
                  AppColors.accentSuccess,
                  () => widget.onMove(true),
                ),
              if (session.can('inventory:adjust')) ...[
                const SizedBox(width: 8),
                _action(
                  'Issue Stock',
                  Icons.remove_rounded,
                  AppColors.accentDanger,
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
                  label: const Text(
                    'History',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
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
                    builder: (_, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Skeleton(height: 60, radius: 12),
                        );
                      }
                      if (snap.hasError) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            snap.error.toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.accentDanger,
                            ),
                          ),
                        );
                      }
                      final rows = snap.data ?? const [];
                      if (rows.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Nothing has moved yet.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        );
                      }
                      return Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            for (final (i, t) in rows.indexed)
                              Padding(
                                padding: EdgeInsets.only(
                                  bottom: i == rows.length - 1 ? 0 : 10,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      t.quantity > 0
                                          ? Icons.south_west_rounded
                                          : Icons.north_east_rounded,
                                      size: 14,
                                      color: t.quantity > 0
                                          ? AppColors.accentSuccess
                                          : AppColors.accentDanger,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        [
                                          reasonLabel(t.reason),
                                          if (t.performedBy.isNotEmpty)
                                            t.performedBy,
                                          relativeTime(t.timestamp),
                                        ].join(' • '),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${t.quantity > 0 ? '+' : ''}${t.quantity} → ${t.balanceAfter}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ).animate().fadeIn(delay: (30 * i).ms),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _meta(String label, String value) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: '$label ',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        TextSpan(
          text: value,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    ),
    style: const TextStyle(fontSize: 11),
  );

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
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    ),
  );
}
