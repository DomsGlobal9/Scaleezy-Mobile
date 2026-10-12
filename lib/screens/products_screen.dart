import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../api/api_repository.dart';
import '../api/shop_context.dart';
import '../models/inventory_models.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import '../widgets/async_state.dart';
import '../widgets/ui.dart';
import 'product_detail_screen.dart';

/// The server's product sorts, as a shopkeeper would say them.
enum _Sort {
  newest('Newest first', 'createdAt', 'desc'),
  updated('Recently changed', 'updatedAt', 'desc'),
  nameAz('Name A–Z', 'title', 'asc'),
  priceLow('Price: low to high', 'basePrice', 'asc'),
  priceHigh('Price: high to low', 'basePrice', 'desc');

  final String label;
  final String field;
  final String order;
  const _Sort(this.label, this.field, this.order);
}

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _repo = ApiRepository();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _count = NumberFormat.decimalPattern('en_IN');

  static const _categories = ['ALL', 'WOMEN', 'MEN', 'KIDS', 'UNISEX'];
  // null = the server's default of active + draft.
  static const _statuses = <String?, String>{
    null: 'Active & Drafts',
    'ACTIVE': 'Published only',
    'DRAFT': 'Drafts only',
    'OUT_OF_STOCK': 'Out of stock',
    'ARCHIVED': 'Archived',
  };

  String _category = 'ALL';
  String? _status;
  _Sort _sort = _Sort.newest;
  bool _grid = true;

  final List<ProductItem> _products = [];
  int _page = 0;
  int _total = 0;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;
  int _requestId = 0;
  int _seenRevision = -1;
  Timer? _debounce;

  bool get _filtered => _status != null || _sort != _Sort.newest;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.extentAfter < 600) _loadMore();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final revision = ShopScope.of(context).revision;
    if (revision != _seenRevision) {
      _seenRevision = revision;
      _reload();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    _requestId++;
    setState(() {
      _products.clear();
      _page = 0;
      _hasMore = true;
      _loading = false;
      _error = null;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    final id = _requestId;
    setState(() => _loading = true);
    try {
      final result = await _repo.getProducts(
        page: _page + 1,
        search: _searchController.text,
        category: _category == 'ALL' ? null : _category,
        status: _status,
        sortBy: _sort.field,
        order: _sort.order,
      );
      if (!mounted || id != _requestId) return;
      setState(() {
        _products.addAll(result.items);
        _page = result.page;
        _total = result.total;
        _hasMore = result.hasMore;
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String _) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _reload);
  }

  Future<void> _open(ProductItem p) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProductDetailScreen(product: p)),
    );
    if (changed == true) _reload();
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Widget choice(String label, bool selected, VoidCallback onTap) =>
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 8),
                child: ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  showCheckmark: false,
                  selectedColor: AppColors.textPrimary,
                  backgroundColor: AppColors.bgSurface,
                  side: BorderSide.none,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppColors.textSecondary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  onSelected: (_) => setSheet(onTap),
                ),
              );
          return SafeArea(
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
                  const SizedBox(height: 16),
                  const Text(
                    'Sort by',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    children: [
                      for (final s in _Sort.values)
                        choice(s.label, _sort == s, () => _sort = s),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Show',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    children: [
                      for (final e in _statuses.entries)
                        choice(
                          e.value,
                          _status == e.key,
                          () => _status = e.key,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => setSheet(() {
                          _sort = _Sort.newest;
                          _status = null;
                        }),
                        child: const Text('Reset'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _reload();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accentGold,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Show results',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
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
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Products',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.7,
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Text(
                            _page == 0
                                ? 'Loading…'
                                : '${_count.format(_total)} ${_total == 1 ? 'product' : 'products'}',
                            key: ValueKey('$_total-$_page'),
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
                  _iconButton(
                    _grid
                        ? Icons.view_agenda_outlined
                        : Icons.grid_view_rounded,
                    () => setState(() => _grid = !_grid),
                  ),
                  const SizedBox(width: 8),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _iconButton(Icons.tune_rounded, _showFilters),
                      if (_filtered)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.accentGold,
                              shape: BoxShape.circle,
                            ),
                          ).animate().scale(),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.bgCard,
                  hintText: 'Search by name or product code',
                  hintStyle: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            _reload();
                          },
                        ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.borderLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: AppColors.accentGold,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final cat = _categories[i];
                  final selected = cat == _category;
                  return Pressable(
                    onTap: () {
                      if (selected) return;
                      setState(() => _category = cat);
                      _reload();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.accentGold
                            : AppColors.bgCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? AppColors.accentGold
                              : AppColors.borderLight,
                        ),
                      ),
                      child: Text(
                        cat == 'ALL'
                            ? 'All'
                            : cat[0] + cat.substring(1).toLowerCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: selected
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap) => Pressable(
    onTap: onTap,
    child: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: AppColors.cardShadow,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (c, a) => RotationTransition(
          turns: Tween(begin: 0.75, end: 1.0).animate(a),
          child: c,
        ),
        child: Icon(
          icon,
          key: ValueKey(icon),
          size: 20,
          color: AppColors.textPrimary,
        ),
      ),
    ),
  );

  Widget _buildBody() {
    if (_products.isEmpty && _loading) return _skeleton();
    if (_products.isEmpty && _error != null) {
      return ErrorView(message: _error!, onRetry: _reload);
    }
    if (_products.isEmpty) {
      return ErrorView(
        message: _searchController.text.isEmpty
            ? 'No products here yet.'
            : 'Nothing matches "${_searchController.text}".',
      );
    }

    final footer = _hasMore || _error != null;
    Widget footerWidget() => Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: _error != null
          ? TextButton(
              onPressed: _loadMore,
              child: Text('$_error  Tap to retry.'),
            )
          : const Center(
              child: CircularProgressIndicator(
                color: AppColors.accentGold,
                strokeWidth: 2.5,
              ),
            ),
    );

    return RefreshIndicator(
      color: AppColors.accentGold,
      onRefresh: _reload,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _grid
            ? CustomScrollView(
                key: const ValueKey('grid'),
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    sliver: SliverGrid.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: 0.58,
                          ),
                      itemCount: _products.length,
                      itemBuilder: (_, i) => _GridCard(
                        product: _products[i],
                        onTap: () => _open(_products[i]),
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
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                itemCount: _products.length + (footer ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => i == _products.length
                    ? footerWidget()
                    : _ListCard(
                        product: _products[i],
                        onTap: () => _open(_products[i]),
                      ).entrance(i % 20),
              ),
      ),
    );
  }

  Widget _skeleton() => GridView.builder(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 0.58,
    ),
    itemCount: 6,
    itemBuilder: (_, _) => const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Skeleton(height: double.infinity, radius: 20)),
        SizedBox(height: 10),
        Skeleton(height: 12, width: 120, radius: 4),
        SizedBox(height: 6),
        Skeleton(height: 12, width: 70, radius: 4),
      ],
    ),
  );
}

/// Stock pill shown over a photo.
Widget _stockBadge(ProductItem p) {
  final (label, color) = p.totalUnits == 0
      ? ('Sold out', AppColors.accentDanger)
      : p.lowStockVariants > 0
      ? ('${p.totalUnits} • low', AppColors.accentWarning)
      : ('${p.totalUnits} pcs', AppColors.accentSuccess);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(20),
      boxShadow: AppColors.cardShadow,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    ),
  );
}

/// Up to four colour photos, overlapping, then "+N".
Widget _colourStack(ProductItem p) {
  final withPhoto = p.variants.where((v) => v.photoUrl != null).toList();
  final seen = <String>{};
  final distinct = withPhoto
      .where((v) => seen.add(v.photoUrl!))
      .take(4)
      .toList();
  final more = p.variantCount - distinct.length;
  if (distinct.isEmpty) {
    return Text(
      '${p.variantCount} ${p.variantCount == 1 ? 'variant' : 'variants'}',
      style: const TextStyle(
        fontSize: 11,
        color: AppColors.textMuted,
        fontWeight: FontWeight.w600,
      ),
    );
  }
  // A Stack of only Positioned children takes its size from its parent, and inside a Row
  // that width is unbounded -- so the width is spelled out.
  return SizedBox(
    height: 22,
    width: (distinct.length - 1) * 15.0 + 22 + (more > 0 ? 34 : 0),
    child: Stack(
      children: [
        for (final (i, v) in distinct.indexed)
          Positioned(
            left: i * 15.0,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: ClipOval(
                child: NetImage(
                  url: v.photoUrl,
                  width: 18,
                  height: 18,
                  radius: 0,
                ),
              ),
            ),
          ),
        if (more > 0)
          Positioned(
            left: distinct.length * 15.0 + 8,
            top: 3,
            child: Text(
              '+$more',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    ),
  );
}

class _GridCard extends StatelessWidget {
  final ProductItem product;
  final VoidCallback onTap;
  const _GridCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = product;
    return Pressable(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Hero(
                    tag: ProductDetailScreen.heroTag(p.id),
                    child: NetImage(url: p.coverImageUrl, radius: 20),
                  ),
                ),
                Positioned(top: 8, right: 8, child: _stockBadge(p)),
                if (p.status != 'ACTIVE')
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        p.status.replaceAll('_', ' '),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            p.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                formatRupees(p.basePrice),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: AppColors.accentGold,
                ),
              ),
              const Spacer(),
              _colourStack(p),
            ],
          ),
        ],
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  final ProductItem product;
  final VoidCallback onTap;
  const _ListCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = product;
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          children: [
            Hero(
              tag: ProductDetailScreen.heroTag(p.id),
              child: NetImage(
                url: p.coverImageUrl,
                width: 76,
                height: 92,
                radius: 14,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [p.category, if (p.fabric.isNotEmpty) p.fabric].join(' • '),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    p.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    p.productCode,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        formatRupees(p.basePrice),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: AppColors.accentGold,
                        ),
                      ),
                      const Spacer(),
                      _stockBadge(p),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
