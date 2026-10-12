import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import 'package:scaleezy/app/app_routes.dart';
import 'package:scaleezy/core/shop/shop_context.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/core/utils/labels.dart';
import 'package:scaleezy/core/utils/money.dart';
import 'package:scaleezy/core/widgets/async_state.dart';
import 'package:scaleezy/core/widgets/status_pill.dart';
import 'package:scaleezy/core/widgets/ui.dart';
import 'package:scaleezy/features/products/data/product_models.dart';
import 'package:scaleezy/features/products/presentation/product_detail_screen.dart';
import 'package:scaleezy/features/products/presentation/view_models/products_view_model.dart';
import 'package:scaleezy/features/products/presentation/widgets/stock_pill.dart';

class ProductsScreen extends StatefulWidget {
  /// Tests pass their own; otherwise the screen makes and owns one.
  final ProductsViewModel? viewModel;

  const ProductsScreen({super.key, this.viewModel});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  late final ProductsViewModel _vm = widget.viewModel ?? ProductsViewModel();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _count = NumberFormat.decimalPattern('en_IN');
  int _seenRevision = -1;

  @override
  void initState() {
    super.initState();
    _vm.loadCategories();
    _scrollController.addListener(() {
      if (_scrollController.position.extentAfter < 600) _vm.loadMore();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final revision = ShopScope.of(context).revision;
    if (revision != _seenRevision) {
      _seenRevision = revision;
      _vm.reload();
    }
  }

  @override
  void dispose() {
    if (widget.viewModel == null) _vm.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _open(ProductItem p) async {
    final changed = await AppRoutes.productDetail(context, p);
    // Null after a swipe back, when nobody knows: reload unless it said nothing changed.
    if (changed != false) _vm.reload();
  }

  void _showFilters() {
    var sort = _vm.sort;
    var status = _vm.status;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final type = Theme.of(ctx).textTheme;
          Widget choice(String label, bool selected, VoidCallback onTap) =>
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 8),
                child: ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  showCheckmark: false,
                  onSelected: (_) => setSheet(onTap),
                ),
              );
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sort by', style: type.titleSmall),
                  const SizedBox(height: 10),
                  Wrap(
                    children: [
                      for (final s in ProductSort.values)
                        choice(s.label, sort == s, () => sort = s),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Show', style: type.titleSmall),
                  const SizedBox(height: 10),
                  Wrap(
                    children: [
                      for (final e in ProductsViewModel.statuses.entries)
                        choice(e.value, status == e.key, () => status = e.key),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => setSheet(() {
                          sort = ProductSort.newest;
                          status = null;
                        }),
                        child: const Text('Reset'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _vm.applyFilters(sort, status);
                        },
                        child: const Text('Show results'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
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
    final categories = _vm.categories;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(
              title: 'Products',
              subtitle: _vm.page == 0
                  ? 'Loading…'
                  : '${_count.format(_vm.total)} ${_vm.total == 1 ? 'product' : 'products'}',
              actions: [
                IconButton(
                  tooltip: _vm.grid ? 'List' : 'Photos',
                  onPressed: _vm.toggleView,
                  icon: Icon(
                    _vm.grid
                        ? Icons.view_agenda_outlined
                        : Icons.grid_view_rounded,
                  ),
                ),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      tooltip: 'Sort and filter',
                      onPressed: _showFilters,
                      icon: const Icon(Icons.tune_rounded),
                    ),
                    if (_vm.isFiltered)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: c.brandSolid,
                            shape: BoxShape.circle,
                          ),
                        ).animate().scale(),
                      ),
                  ],
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: SearchField(
                controller: _searchController,
                hint: 'Search by name or product code',
                onChanged: _vm.search,
                onClear: _vm.clearSearch,
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ChoiceChip(
                  label: Text(categories[i].label),
                  selected: categories[i].value == _vm.category,
                  showCheckmark: false,
                  onSelected: (_) => _vm.selectCategory(categories[i].value),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final products = _vm.products;
    final error = _vm.error;
    if (products.isEmpty && _vm.loading) return _skeleton();
    if (products.isEmpty && error != null) {
      return ErrorView.fromError(error, what: 'products', onRetry: _vm.reload);
    }
    if (products.isEmpty) {
      return EmptyState(
        Icons.inventory_2_outlined,
        _vm.query.isEmpty
            ? 'No products added yet.'
            : 'Nothing matches "${_vm.query}".',
      );
    }

    final footer = _vm.hasMore || error != null;
    Widget footerWidget() => Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: error != null
          ? TextButton(
              onPressed: _vm.loadMore,
              child: Text('${error.message}  Tap to retry.'),
            )
          : const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
    );

    return RefreshIndicator(
      onRefresh: _vm.reload,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _vm.grid
            ? CustomScrollView(
                key: const ValueKey('grid'),
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    sliver: SliverGrid.builder(
                      gridDelegate: _gridShape,
                      itemCount: products.length,
                      itemBuilder: (_, i) => _GridCard(
                        product: products[i],
                        onTap: () => _open(products[i]),
                      ).entrance(i % 20),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: footer ? footerWidget() : const SizedBox(height: 32),
                  ),
                ],
              )
            : ListView.separated(
                key: const ValueKey('list'),
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                itemCount: products.length + (footer ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => i == products.length
                    ? footerWidget()
                    : _ListCard(
                        product: products[i],
                        category: _vm.categoryLabel(products[i].category),
                        onTap: () => _open(products[i]),
                      ).entrance(i % 20),
              ),
      ),
    );
  }

  static const _gridShape = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    mainAxisSpacing: 10,
    crossAxisSpacing: 10,
    childAspectRatio: 0.5,
  );

  Widget _skeleton() => GridView.builder(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
    gridDelegate: _gridShape,
    itemCount: 6,
    itemBuilder: (_, _) => const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Skeleton(height: double.infinity, radius: 12)),
        SizedBox(height: 10),
        Skeleton(height: 12, width: 120, radius: 4),
        SizedBox(height: 6),
        Skeleton(height: 12, width: 70, radius: 4),
      ],
    ),
  );
}

StockPill _stock(ProductItem p) =>
    StockPill(p.totalUnits, low: p.lowStockVariants > 0);

/// The website's photo card: a 3:4 picture in a bordered card, the title on two lines, then
/// the code, the price and the stock.
class _GridCard extends StatelessWidget {
  final ProductItem product;
  final VoidCallback onTap;
  const _GridCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = product;
    final c = context.colors;
    final type = Theme.of(context).textTheme;
    return Pressable(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Hero(
                      tag: ProductDetailScreen.heroTag(p.id),
                      child: NetImage(url: p.coverImageUrl, radius: 0),
                    ),
                  ),
                  if (p.status != 'ACTIVE')
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _PhotoBadge(describe(productStatuses, p.status)),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 36,
                    child: Text(
                      p.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: type.bodySmall!.copyWith(
                        color: c.text,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    p.productCode,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: type.labelMedium!.copyWith(
                      color: c.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formatRupees(p.basePrice),
                    style: type.bodyMedium!.copyWith(
                      fontWeight: FontWeight.w500,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 6),
                  _stock(p),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A status written over a photograph: dark glass, white text, so it reads on any picture.
class _PhotoBadge extends StatelessWidget {
  final String label;
  const _PhotoBadge(this.label);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.labelMedium!.copyWith(fontSize: 10, color: Colors.white),
    ),
  );
}

/// The phone list row: photo, title, code · category, then price, stock and status.
class _ListCard extends StatelessWidget {
  final ProductItem product;
  final String category;
  final VoidCallback onTap;
  const _ListCard({
    required this.product,
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = product;
    final type = Theme.of(context).textTheme;
    final status = describeStatus(productStatuses, p.status);
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Hero(
            tag: ProductDetailScreen.heroTag(p.id),
            child: NetImage(
              url: p.coverImageUrl,
              width: 64,
              height: 80,
              radius: 8,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: type.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    p.productCode,
                    if (category.isNotEmpty) category,
                    if (p.fabric.isNotEmpty) p.fabric,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.bodySmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      formatRupees(p.basePrice),
                      style: type.titleSmall!.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    _stock(p),
                    if (p.status != 'ACTIVE')
                      StatusPill(status.label, status.tone),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
