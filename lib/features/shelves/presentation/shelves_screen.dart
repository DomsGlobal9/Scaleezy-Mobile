import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:scaleezy/app/app_routes.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/shop/shop_context.dart';
import 'package:scaleezy/core/shop/shop_models.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/core/widgets/async_state.dart';
import 'package:scaleezy/core/widgets/scan_sheet.dart';
import 'package:scaleezy/core/widgets/ui.dart';
import 'package:scaleezy/features/shelves/data/shelf_models.dart';
import 'package:scaleezy/features/shelves/presentation/view_models/find_piece_view_model.dart';
import 'package:scaleezy/features/shelves/presentation/view_models/move_sheet_view_model.dart';
import 'package:scaleezy/features/shelves/presentation/view_models/shelves_view_model.dart';
import 'package:scaleezy/features/shelves/presentation/view_models/spot_view_model.dart';
import 'package:scaleezy/features/shelves/presentation/view_models/waiting_to_shelve_view_model.dart';

IconData _kindIcon(String kind) => switch (kind) {
  'AREA' => Icons.meeting_room_outlined,
  'RACK' => Icons.shelves,
  'CUPBOARD' => Icons.door_sliding_outlined,
  'BOX' => Icons.inventory_2_outlined,
  'STACK' => Icons.layers_outlined,
  'BUNDLE' => Icons.all_inbox_outlined,
  'RAIL' => Icons.checkroom_outlined,
  _ => Icons.view_agenda_outlined, // SHELF
};

String _kindLabel(String kind) =>
    kind.isEmpty ? 'Spot' : kind[0] + kind.substring(1).toLowerCase();

/// Scan a shelf label; the caller's view model looks it up. Shared by the overview and the
/// pickers.
Future<String?> _scanShelfLabel(BuildContext context) => showScanSheet(
  context,
  title: 'Scan the shelf label',
  hint: 'Point at the label on the shelf',
);

class ShelvesScreen extends StatefulWidget {
  /// Tests pass their own; otherwise the screen makes and owns one.
  final ShelvesViewModel? viewModel;

  const ShelvesScreen({super.key, this.viewModel});

  @override
  State<ShelvesScreen> createState() => _ShelvesScreenState();
}

class _ShelvesScreenState extends State<ShelvesScreen> {
  late final ShelvesViewModel _vm = widget.viewModel ?? ShelvesViewModel();

  /// Racks that are opened out to show what is inside.
  final Set<String> _open = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Until a store is known, try again whenever the shop's stores change.
    if (_vm.location == null) {
      final shop = ShopScope.of(context);
      _vm.start(shop.selectedLocation, shop.locations);
    }
  }

  @override
  void dispose() {
    if (widget.viewModel == null) _vm.dispose();
    super.dispose();
  }

  void _pickLocation(StockLocation loc) {
    if (loc.id == _vm.location?.id) return;
    _open.clear();
    _vm.pickLocation(loc);
  }

  Future<void> _openSpot(String spotId) async {
    await AppRoutes.spot(context, spotId);
    _vm.load();
  }

  Future<void> _scan() async {
    final code = await _scanShelfLabel(context);
    if (code == null || !mounted) return;
    final error = await _vm.scanLabel(code);
    if (!mounted) return;
    if (error != null) {
      showMessage(context, error, error: true);
      return;
    }
    _openSpot(_vm.scanned!.spotId);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => _buildScreen(),
    );
  }

  Widget _buildScreen() {
    final shop = ShopScope.of(context);
    final stores = ShelvesViewModel.storesOf(shop.locations);
    final tree = _vm.tree;

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accentGold,
          onRefresh: _vm.load,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              PageHeader(title: 'Shelves', subtitle: _vm.location?.name),
              if (stores.length > 1)
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: stores.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final l = stores[i];
                      final sel = l.id == _vm.location?.id;
                      return Pressable(
                        onTap: () => _pickLocation(l),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: sel
                                ? AppColors.textPrimary
                                : AppColors.bgCard,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel
                                  ? AppColors.textPrimary
                                  : AppColors.borderLight,
                            ),
                          ),
                          child: Text(
                            l.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: sel
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: _bigAction(
                        Icons.qr_code_scanner_rounded,
                        'Scan a shelf',
                        'See what is on it',
                        _scan,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _bigAction(
                        Icons.travel_explore_rounded,
                        'Where is it?',
                        'Which shelf is it on?',
                        () {
                          AppRoutes.findPiece(
                            context,
                            locationId: _vm.location?.id,
                          );
                        },
                      ),
                    ),
                  ],
                ).entrance(0),
              ),
              if (SessionScope.of(context).can('shelf:putaway'))
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: _bigAction(
                    Icons.playlist_add_check_rounded,
                    'Pick orders',
                    'Walk the shelves once to collect orders',
                    () async {
                      await AppRoutes.pickOrders(
                        context,
                        location: _vm.location,
                      );
                      _vm.load();
                    },
                  ).entrance(0),
                ),
              const SizedBox(height: 16),
              if (tree == null && _vm.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: ErrorView(message: _vm.error!, onRetry: _vm.load),
                )
              else if (tree == null)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      Skeleton(height: 120, radius: 22),
                      SizedBox(height: 16),
                      Skeleton(height: 60, radius: 16),
                      SizedBox(height: 8),
                      Skeleton(height: 60, radius: 16),
                    ],
                  ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _summary(tree).entrance(1),
                ),
                const SizedBox(height: 22),
                if (tree.count == 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: _Note(
                      icon: Icons.shelves,
                      text:
                          'No racks or shelves are set up for this store yet. They are laid out once from the web app; '
                          'after that, everything here works from the phone.',
                    ),
                  )
                else ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: SectionHeader(title: 'Racks & shelves'),
                  ),
                  for (final (i, s) in tree.spots.indexed)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _branch(s, 0).entrance(2 + i),
                    ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _bigAction(
    IconData icon,
    String title,
    String sub,
    VoidCallback onTap,
  ) => SurfaceCard(
    onTap: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.accentGoldLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.accentGold, size: 22),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        Text(
          sub,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  Widget _summary(ShelfTree t) {
    final share = t.totalPieces == 0 ? 0.0 : t.onShelves / t.totalPieces;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            height: 76,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: share),
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, _) => CircularProgressIndicator(
                      value: v,
                      strokeWidth: 7,
                      strokeCap: StrokeCap.round,
                      backgroundColor: Colors.white12,
                      color: const Color(0xFFFDE68A),
                    ),
                  ),
                ),
                Text(
                  '${(share * 100).round()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ON SHELVES',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  '${t.onShelves} of ${t.totalPieces} pieces',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                if (t.notShelved > 0 && t.count > 0)
                  Pressable(
                    onTap: () async {
                      await AppRoutes.waitingToShelve(
                        context,
                        locationId: t.locationId,
                      );
                      _vm.load();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDE68A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${t.notShelved} waiting to be put away',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, size: 16),
                        ],
                      ),
                    ),
                  )
                else
                  Text(
                    '${t.count} spots',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _branch(ShelfSpot s, int depth) {
    final open = _open.contains(s.id);
    final row = Container(
      margin: EdgeInsets.only(left: depth * 18.0, bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: ListTile(
        onTap: () {
          if (s.holdsStock) {
            _openSpot(s.id);
          } else {
            setState(() => open ? _open.remove(s.id) : _open.add(s.id));
          }
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            _kindIcon(s.kind),
            size: 18,
            color: AppColors.textSecondary,
          ),
        ),
        title: Text(
          s.title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        subtitle: Text(
          [
            _kindLabel(s.kind),
            if (s.name != null) s.address,
            if (s.isShopFloor) 'Shop floor',
            if (!s.holdsStock) '${s.children.length} inside',
          ].join(' • '),
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${s.branchPieces}',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
            const SizedBox(width: 2),
            const Text(
              'pcs',
              style: TextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
            const SizedBox(width: 4),
            AnimatedRotation(
              turns: s.holdsStock ? 0 : (open ? 0.25 : 0),
              duration: const Duration(milliseconds: 200),
              child: const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
    return Column(
      children: [
        row,
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: open
              ? Column(
                  children: [for (final c in s.children) _branch(c, depth + 1)],
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

// ---- One shelf ------------------------------------------------------------------------------------

class SpotScreen extends StatefulWidget {
  final String spotId;

  /// Tests pass their own; otherwise the screen makes and owns one.
  final SpotViewModel? viewModel;

  const SpotScreen({super.key, required this.spotId, this.viewModel});

  @override
  State<SpotScreen> createState() => _SpotScreenState();
}

class _SpotScreenState extends State<SpotScreen> {
  late final SpotViewModel _vm =
      widget.viewModel ?? SpotViewModel(widget.spotId);

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

  Future<void> _moveOff(ShelfItem item) async {
    final s = _vm.spot!;
    final result = await showModalBottomSheet<(ShelfSpot?, int)>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => _MoveSheet(
        item: item,
        locationId: s.locationId,
        excludeSpotId: s.spotId,
        maxQty: item.quantity,
      ),
    );
    if (result == null || !mounted) return;
    final (to, qty) = result;
    final error = await _vm.move(item, to, qty);
    if (!mounted) return;
    if (error != null) {
      showMessage(context, error, error: true);
      return;
    }
    final warning = _vm.warning;
    showMessage(
      context,
      warning ??
          (to == null ? 'Taken off the shelf.' : 'Moved $qty to ${to.title}.'),
      success: warning == null,
    );
  }

  Future<void> _putHere() async {
    final s = _vm.spot!;
    await AppRoutes.waitingToShelve(
      context,
      locationId: s.locationId,
      target: s,
    );
    _vm.load();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => _buildScreen(),
    );
  }

  Widget _buildScreen() {
    final s = _vm.spot;
    final canMove = SessionScope.of(context).can('shelf:putaway');
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      floatingActionButton: s != null && s.holdsStock && canMove
          ? FloatingActionButton.extended(
              onPressed: _putHere,
              backgroundColor: AppColors.accentGold,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Put away',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ).animate().scale(delay: 300.ms, curve: Curves.easeOutBack)
          : null,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accentGold,
          onRefresh: _vm.load,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              PageHeader(
                title: s?.name ?? s?.address ?? 'Shelf',
                subtitle: s == null
                    ? null
                    : '${_kindLabel(s.kind)} • ${s.locationName}',
              ),
              if (s == null && _vm.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 80),
                  child: ErrorView(message: _vm.error!, onRetry: _vm.load),
                )
              else if (s == null)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Skeleton(height: 200, radius: 22),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SurfaceCard(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.accentGoldLight,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            _kindIcon(s.kind),
                            color: AppColors.accentGold,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.address,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              if (s.capacity != null) ...[
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: (s.total / s.capacity!).clamp(0, 1),
                                    minHeight: 6,
                                    backgroundColor: AppColors.bgSurface,
                                    color: s.overCapacity
                                        ? AppColors.accentDanger
                                        : AppColors.accentSuccess,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${s.total} of ${s.capacity} it is meant for',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: s.overCapacity
                                        ? AppColors.accentDanger
                                        : AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            Text(
                              '${s.total}',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const Text(
                              'pieces',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ).entrance(0),
                ),
                const SizedBox(height: 18),
                if (!s.holdsStock)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: _Note(
                      icon: Icons.account_tree_outlined,
                      text:
                          'This holds other shelves. Open one of those to see pieces.',
                    ),
                  )
                else if (s.items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: _Note(
                      icon: Icons.inbox_outlined,
                      text: 'This shelf is empty.',
                    ),
                  )
                else ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: SectionHeader(title: 'On this shelf'),
                  ),
                  for (final (i, item) in s.items.indexed)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                      child: _ItemRow(
                        item: item,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '×${item.quantity}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (canMove)
                              IconButton(
                                tooltip: 'Move',
                                onPressed: () => _moveOff(item),
                                icon: const Icon(
                                  Icons.swap_horiz_rounded,
                                  color: AppColors.accentGold,
                                ),
                              ),
                          ],
                        ),
                      ).entrance(1 + i),
                    ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---- Where is it? ---------------------------------------------------------------------------------

class FindPieceScreen extends StatefulWidget {
  final String? locationId;
  final String? initialQuery;

  /// Tests pass their own; otherwise the screen makes and owns one.
  final FindPieceViewModel? viewModel;

  const FindPieceScreen({
    super.key,
    this.locationId,
    this.initialQuery,
    this.viewModel,
  });

  @override
  State<FindPieceScreen> createState() => _FindPieceScreenState();
}

class _FindPieceScreenState extends State<FindPieceScreen> {
  late final FindPieceViewModel _vm =
      widget.viewModel ?? FindPieceViewModel(locationId: widget.locationId);
  final _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    final q = widget.initialQuery;
    if (q != null && q.isNotEmpty) {
      _query.text = q;
      _vm.search(q);
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
    final results = _vm.results;
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(
              title: 'Where is it?',
              subtitle: 'Search by name, SKU or barcode',
              actions: [
                IconButton(
                  tooltip: 'Scan its tag',
                  icon: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: AppColors.accentGold,
                  ),
                  onPressed: () async {
                    final code = await showScanSheet(
                      context,
                      title: 'Scan the piece',
                    );
                    if (code != null) {
                      _query.text = code;
                      _vm.search(code);
                    }
                  },
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: SearchField(
                controller: _query,
                hint: 'e.g. red banarasi, SKU-104, 8901…',
                onChanged: (v) {
                  setState(() {}); // shows or hides the clear button
                  _vm.typed(v);
                },
              ),
            ),
            if (_vm.loading)
              const LinearProgressIndicator(
                minHeight: 2,
                color: AppColors.accentGold,
                backgroundColor: Colors.transparent,
              ),
            Expanded(
              child: _vm.error != null
                  ? ErrorView(
                      message: _vm.error!,
                      onRetry: () => _vm.search(_query.text),
                    )
                  : results == null
                  ? const _Hint(
                      icon: Icons.travel_explore_rounded,
                      text: 'Type or scan to see which shelf a piece is on.',
                    )
                  : results.isEmpty
                  ? const _Hint(
                      icon: Icons.search_off_rounded,
                      text: 'Nothing matches that.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                      itemCount: results.length,
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _whereCard(results[i]).entrance(i),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _whereCard(WhereItem w) {
    final places = _vm.placesOf(w);
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ItemRow(item: w.item, bare: true),
          const SizedBox(height: 12),
          if (places.isEmpty)
            const Text(
              'None in stock anywhere.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            )
          else
            for (final p in places) ...[
              Row(
                children: [
                  const Icon(
                    Icons.place_rounded,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      p.location,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${p.total} pcs${p.held > 0 ? ' • ${p.held} held' : ''}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final sh in p.shelves)
                    Pressable(
                      onTap: () => AppRoutes.spot(context, sh.spotId),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentGoldLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.accentGoldBorder),
                        ),
                        child: Text(
                          '${sh.name ?? sh.address}  ×${sh.quantity}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accentGold,
                          ),
                        ),
                      ),
                    ),
                  if (p.usesShelves && p.notShelved > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${p.notShelved} not shelved',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  if (!p.usesShelves)
                    const Text(
                      'This store does not use shelves',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

// ---- Waiting to be put away -------------------------------------------------------------------

class WaitingToShelveScreen extends StatefulWidget {
  final String locationId;
  final String locationName;

  /// When opened from a shelf, pieces go straight there.
  final SpotContents? target;

  /// Tests pass their own; otherwise the screen makes and owns one.
  final WaitingToShelveViewModel? viewModel;

  const WaitingToShelveScreen({
    super.key,
    required this.locationId,
    required this.locationName,
    this.target,
    this.viewModel,
  });

  @override
  State<WaitingToShelveScreen> createState() => _WaitingToShelveScreenState();
}

class _WaitingToShelveScreenState extends State<WaitingToShelveScreen> {
  late final WaitingToShelveViewModel _vm =
      widget.viewModel ?? WaitingToShelveViewModel(widget.locationId);

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

  Future<void> _putAway(NotShelvedItem n) async {
    final result = await showModalBottomSheet<(ShelfSpot?, int)>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => _MoveSheet(
        item: n.item,
        locationId: widget.locationId,
        maxQty: n.notShelved,
        fixedTarget: widget.target,
        requireTarget: true,
      ),
    );
    if (result == null || result.$1 == null || !mounted) return;
    final (to, qty) = result;
    final error = await _vm.putAway(n, to!, qty);
    if (!mounted) return;
    if (error != null) {
      showMessage(context, error, error: true);
      return;
    }
    final warning = _vm.warning;
    showMessage(
      context,
      warning ?? 'Put $qty on ${to.title}.',
      success: warning == null,
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
    final items = _vm.items;
    final waiting = _vm.waiting;
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accentGold,
          onRefresh: _vm.load,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              PageHeader(
                title: widget.target == null
                    ? 'Waiting to be put away'
                    : 'Put on ${widget.target!.name ?? widget.target!.address}',
                subtitle: items == null
                    ? widget.locationName
                    : '$waiting pieces in ${widget.locationName}',
              ),
              if (items == null && _vm.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 80),
                  child: ErrorView(message: _vm.error!, onRetry: _vm.load),
                )
              else if (items == null)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Skeleton(height: 240, radius: 20),
                )
              else if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: _Note(
                    icon: Icons.task_alt_rounded,
                    text: 'Everything in this store is on a shelf.',
                  ),
                )
              else
                for (final (i, n) in items.indexed)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: _ItemRow(
                      item: n.item,
                      onTap: SessionScope.of(context).can('shelf:putaway')
                          ? () => _putAway(n)
                          : null,
                      trailing: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${n.notShelved}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.accentGold,
                            ),
                          ),
                          Text(
                            'of ${n.total}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ).entrance(i),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- Choose a shelf + how many ------------------------------------------------------------------

class _MoveSheet extends StatefulWidget {
  final ShelfItem item;
  final String locationId;
  final String? excludeSpotId;
  final int maxQty;
  final SpotContents? fixedTarget;
  final bool requireTarget;

  const _MoveSheet({
    required this.item,
    required this.locationId,
    required this.maxQty,
    this.excludeSpotId,
    this.fixedTarget,
    this.requireTarget = false,
  });

  @override
  State<_MoveSheet> createState() => _MoveSheetState();
}

class _MoveSheetState extends State<_MoveSheet> {
  late final _vm = MoveSheetViewModel(
    locationId: widget.locationId,
    maxQty: widget.maxQty,
    excludeSpotId: widget.excludeSpotId,
    fixedTarget: widget.fixedTarget,
    requireTarget: widget.requireTarget,
  );

  @override
  void initState() {
    super.initState();
    _vm.load();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final code = await _scanShelfLabel(context);
    if (code == null || !mounted) return;
    final error = await _vm.scanTarget(code);
    if (error != null && mounted) showMessage(context, error, error: true);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => _buildSheet(),
    );
  }

  Widget _buildSheet() {
    final spots = _vm.spots;
    final to = _vm.to;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SizedBox(
          height:
              MediaQuery.of(context).size.height *
              (widget.fixedTarget == null ? 0.8 : 0.42),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                child: _ItemRow(item: widget.item, bare: true),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Text(
                      'How many?',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    QuantityStepper(
                      value: _vm.qty,
                      min: 1,
                      max: widget.maxQty,
                      onChanged: _vm.setQty,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (widget.fixedTarget == null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const Text(
                        'To which shelf?',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _scan,
                        icon: const Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 18,
                        ),
                        label: const Text('Scan label'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: TextField(
                    onChanged: _vm.setFilter,
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.bgSurface,
                      hintText: 'Filter shelves',
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _vm.loadingSpots
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.accentGold,
                          ),
                        )
                      : RadioGroup<String>(
                          groupValue: _vm.offShelf ? '__off__' : to?.id,
                          onChanged: (v) => v == '__off__'
                              ? _vm.takeOffShelf()
                              : _vm.choose(spots.firstWhere((s) => s.id == v)),
                          child: ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            children: [
                              if (!widget.requireTarget)
                                RadioListTile<String>(
                                  value: '__off__',
                                  activeColor: AppColors.accentGold,
                                  title: const Text(
                                    'Off the shelf',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: const Text(
                                    'Back to "Not shelved"',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                              for (final s in spots)
                                RadioListTile<String>(
                                  value: s.id,
                                  activeColor: AppColors.accentGold,
                                  title: Text(
                                    s.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${s.address} • ${s.pieces} pcs now',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                            ],
                          ),
                        ),
                ),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Onto ${widget.fixedTarget!.name ?? widget.fixedTarget!.address}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _vm.ready
                        ? () => Navigator.of(context).pop(_vm.result)
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accentGold,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      _vm.offShelf
                          ? 'Take ${_vm.qty} off'
                          : (to == null
                                ? 'Choose a shelf'
                                : 'Move ${_vm.qty} to ${to.title}'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
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
}

// ---- Small pieces ---------------------------------------------------------------------------------

class _ItemRow extends StatelessWidget {
  final ShelfItem item;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool bare;

  const _ItemRow({
    required this.item,
    this.trailing,
    this.onTap,
    this.bare = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        NetImage(url: item.imageUrl, width: 52, height: 52, radius: 14),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                [if (item.label.isNotEmpty) item.label, item.sku].join(' • '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
              if (item.archived)
                const Text(
                  'Archived product',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.accentWarning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
    if (bare) return content;
    return SurfaceCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: content,
    );
  }
}

class _Note extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Note({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => SurfaceCard(
    child: Row(
      children: [
        Icon(icon, color: AppColors.accentGold),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Hint extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Hint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 52,
            color: AppColors.accentGold.withValues(alpha: 0.4),
          ).animate().scale(curve: Curves.easeOutBack),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}
