import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:scaleezy/app/app_routes.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/shop/shop_context.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/core/widgets/async_state.dart';
import 'package:scaleezy/core/widgets/scan_sheet.dart';
import 'package:scaleezy/core/widgets/status_pill.dart';
import 'package:scaleezy/core/widgets/ui.dart';
import 'package:scaleezy/features/shelves/data/shelf_models.dart';
import 'package:scaleezy/features/shelves/presentation/view_models/find_piece_view_model.dart';
import 'package:scaleezy/features/shelves/presentation/view_models/move_sheet_view_model.dart';
import 'package:scaleezy/features/shelves/presentation/view_models/shelves_view_model.dart';
import 'package:scaleezy/features/shelves/presentation/view_models/spot_view_model.dart';
import 'package:scaleezy/features/shelves/presentation/view_models/waiting_to_shelve_view_model.dart';
import 'package:scaleezy/features/shelves/presentation/widgets/shelf_bits.dart';

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

/// "Red · Size M · SKU-1", as the website's `itemDetail`.
String _detail(ShelfItem i) => [
  ?i.colorName,
  if (i.size != null) i.size == 'Free' ? i.size! : 'Size ${i.size}',
  i.sku,
].join(' · ');

const _tabular = [FontFeature.tabularFigures()];

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
  (int, String?)? _seen;

  /// Racks that are opened out to show what is inside.
  final Set<String> _open = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The app's one store; switching it (or the shop loading it) shows that store's shelves.
    final shop = ShopScope.of(context);
    final seen = (shop.revision, shop.selectedLocation?.id);
    if (seen != _seen) {
      _seen = seen;
      _open.clear();
      _vm.show(shop.selectedLocation);
    }
  }

  @override
  void dispose() {
    if (widget.viewModel == null) _vm.dispose();
    super.dispose();
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
    final tree = _vm.tree;
    final error = _vm.error;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _vm.load,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              PageHeader(title: 'Shelves', subtitle: _vm.location?.name),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                    const SizedBox(width: 10),
                    Expanded(
                      child: _bigAction(
                        Icons.travel_explore_rounded,
                        'Where is it?',
                        'Which shelf is it on?',
                        () => AppRoutes.findPiece(context),
                      ),
                    ),
                  ],
                ).entrance(0),
              ),
              if (SessionScope.of(context).can('shelf:putaway'))
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: _bigAction(
                    Icons.playlist_add_check_rounded,
                    'Pick orders',
                    'Walk the shelves once to collect orders',
                    () async {
                      await AppRoutes.pickOrders(context);
                      _vm.load();
                    },
                  ).entrance(0),
                ),
              const SizedBox(height: 16),
              if (_vm.location == null)
                const EmptyState(
                  Icons.place_outlined,
                  'No store is set up yet, so there are no shelves to show.',
                )
              else if (tree == null && error != null)
                ErrorView.fromError(error, what: 'shelves', onRetry: _vm.load)
              else if (tree == null)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      Skeleton(height: 112),
                      SizedBox(height: 16),
                      Skeleton(height: 60),
                      SizedBox(height: 10),
                      Skeleton(height: 60),
                    ],
                  ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _summary(tree).entrance(1),
                ),
                const SizedBox(height: 20),
                if (tree.count == 0)
                  const EmptyState(
                    Icons.shelves,
                    'No racks or shelves here yet',
                    text:
                        'They are laid out once from the website, under Racks & shelves; '
                        'after that, everything here works from the phone.',
                  )
                else ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SectionHeader(title: 'Racks & shelves'),
                  ),
                  for (final (i, s) in tree.spots.indexed)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
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
  ) {
    final c = context.colors;
    final type = Theme.of(context).textTheme;
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: c.input,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: c.text, size: 20),
          ),
          const SizedBox(height: 10),
          Text(title, style: type.titleSmall),
          Text(sub, style: type.bodySmall),
        ],
      ),
    );
  }

  Widget _summary(ShelfTree t) {
    final c = context.colors;
    final type = Theme.of(context).textTheme;
    final share = t.totalPieces == 0 ? 0.0 : t.onShelves / t.totalPieces;
    return SurfaceCard(
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
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
                      strokeWidth: 6,
                      strokeCap: StrokeCap.round,
                      backgroundColor: c.input,
                      color: c.success,
                    ),
                  ),
                ),
                Text(
                  '${(share * 100).round()}%',
                  style: type.titleMedium!.copyWith(fontFeatures: _tabular),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ON SHELVES', style: type.labelSmall),
                const SizedBox(height: 2),
                Text(
                  '${t.onShelves} of ${t.totalPieces} pieces',
                  style: type.titleMedium!.copyWith(fontFeatures: _tabular),
                ),
                const SizedBox(height: 8),
                if (t.notShelved > 0 && t.count > 0)
                  Pressable(
                    onTap: () async {
                      await AppRoutes.waitingToShelve(context);
                      _vm.load();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: tint(c.warning),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              '${t.notShelved} waiting to be put away',
                              style: type.labelMedium!.copyWith(
                                color: c.warning,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: c.warning,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Text('${t.count} spots', style: type.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _branch(ShelfSpot s, int depth) {
    final c = context.colors;
    final type = Theme.of(context).textTheme;
    final open = _open.contains(s.id);
    final row = Padding(
      padding: EdgeInsets.only(left: depth * 16.0, bottom: 10),
      child: SurfaceCard(
        padding: const EdgeInsets.all(14),
        onTap: () {
          if (s.holdsStock) {
            _openSpot(s.id);
          } else {
            setState(() => open ? _open.remove(s.id) : _open.add(s.id));
          }
        },
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: c.input,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_kindIcon(s.kind), size: 18, color: c.textSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  s.name == null
                      ? ShelfAddress(s.address)
                      : Text(s.name!, style: type.titleSmall),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        [
                          _kindLabel(s.kind),
                          if (s.name != null) s.address,
                          if (!s.holdsStock) '${s.children.length} inside',
                        ].join(' · '),
                        style: type.bodySmall,
                      ),
                      if (s.isShopFloor) const ShelfTag(isShopFloor: true),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              '${s.branchPieces}',
              style: type.titleSmall!.copyWith(fontFeatures: _tabular),
            ),
            const SizedBox(width: 4),
            Text(
              'pieces',
              style: type.labelMedium!.copyWith(color: c.textMuted),
            ),
            AnimatedRotation(
              turns: s.holdsStock ? 0 : (open ? 0.25 : 0),
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.chevron_right_rounded, color: c.textMuted),
            ),
          ],
        ),
      ),
    );
    return Column(
      children: [
        row,
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: open
              ? Column(
                  children: [
                    for (final ch in s.children) _branch(ch, depth + 1),
                  ],
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
      showDragHandle: true,
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
    final c = context.colors;
    final type = Theme.of(context).textTheme;
    final s = _vm.spot;
    final error = _vm.error;
    final canMove = SessionScope.of(context).can('shelf:putaway');
    return Scaffold(
      floatingActionButton: s != null && s.holdsStock && canMove
          ? FloatingActionButton.extended(
              onPressed: _putHere,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Put away'),
            ).animate().scale(delay: 300.ms, curve: Curves.easeOutBack)
          : null,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _vm.load,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              PageHeader(
                title: s?.name ?? s?.address ?? 'Shelf',
                subtitle: s == null
                    ? null
                    : '${_kindLabel(s.kind)} · ${s.locationName}',
              ),
              if (s == null && error != null)
                ErrorView.fromError(
                  error,
                  what: 'this shelf',
                  onRetry: _vm.load,
                )
              else if (s == null)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Skeleton(height: 120),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SurfaceCard(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: c.input,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(_kindIcon(s.kind), color: c.text),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ShelfAddress(s.address, big: true),
                              if (s.capacity != null) ...[
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: (s.total / s.capacity!).clamp(0, 1),
                                    minHeight: 6,
                                    backgroundColor: c.input,
                                    color: s.overCapacity
                                        ? c.danger
                                        : c.success,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${s.total} of ${s.capacity} it is meant for',
                                  style: type.labelMedium!.copyWith(
                                    color: s.overCapacity
                                        ? c.danger
                                        : c.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          children: [
                            BigQty('${s.total}'),
                            Text(
                              s.total == 1 ? 'piece' : 'pieces',
                              style: type.labelMedium!.copyWith(
                                color: c.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ).entrance(0),
                ),
                const SizedBox(height: 16),
                if (!s.holdsStock)
                  const EmptyState(
                    Icons.account_tree_outlined,
                    'This holds other shelves',
                    text: 'Open one of those to see pieces.',
                  )
                else if (s.items.isEmpty)
                  const EmptyState(Icons.inbox_outlined, 'This shelf is empty')
                else ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SectionHeader(title: 'On this shelf'),
                  ),
                  for (final (i, item) in s.items.indexed)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: _ItemRow(
                        item: item,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '×${item.quantity}',
                              style: type.titleMedium!.copyWith(
                                fontFeatures: _tabular,
                              ),
                            ),
                            if (canMove)
                              IconButton(
                                tooltip: 'Move',
                                onPressed: () => _moveOff(item),
                                icon: const Icon(Icons.swap_horiz_rounded),
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
  final String? initialQuery;

  /// Tests pass their own; otherwise the screen makes and owns one.
  final FindPieceViewModel? viewModel;

  const FindPieceScreen({super.key, this.initialQuery, this.viewModel});

  @override
  State<FindPieceScreen> createState() => _FindPieceScreenState();
}

class _FindPieceScreenState extends State<FindPieceScreen> {
  late final FindPieceViewModel _vm = widget.viewModel ?? FindPieceViewModel();
  late final _query = TextEditingController(text: widget.initialQuery);
  (int, String?)? _seen;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Searches the app's one store; the first time with the text it was opened with, later
    // again whenever the store changes.
    final shop = ShopScope.of(context);
    final seen = (shop.revision, shop.selectedLocation?.id);
    if (seen != _seen) {
      _seen = seen;
      _vm.locationId = shop.selectedLocation?.id;
      _vm.search(_query.text);
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
    final type = Theme.of(context).textTheme;
    final store = ShopScope.of(context).selectedLocation;
    final results = _vm.results;
    final error = _vm.error;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(
              title: 'Where is it?',
              subtitle: 'Scan a price tag or type a name to find the shelf.',
              actions: [
                IconButton(
                  tooltip: 'Scan its tag',
                  icon: const Icon(Icons.qr_code_scanner_rounded),
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
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: SearchField(
                controller: _query,
                hint: 'Scan a tag, or type saree, SKU, colour…',
                onChanged: (v) {
                  setState(() {}); // shows or hides the clear button
                  _vm.typed(v);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 16, 4),
              child: CheckboxListTile(
                value: _vm.everywhere,
                onChanged: (v) => _vm.setEverywhere(v ?? false, _query.text),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  'Look in every location, not just ${store?.name ?? 'this one'}',
                  style: type.bodySmall,
                ),
              ),
            ),
            SizedBox(
              height: 2,
              child: _vm.loading
                  ? const LinearProgressIndicator(
                      minHeight: 2,
                      backgroundColor: Colors.transparent,
                    )
                  : null,
            ),
            Expanded(
              child: error != null
                  ? ErrorView.fromError(
                      error,
                      what: 'the search results',
                      onRetry: () => _vm.search(_query.text),
                    )
                  : results == null
                  ? const EmptyState(
                      Icons.search_rounded,
                      'Find any piece in seconds',
                      text:
                          'Point the scanner at the price tag, or start typing. '
                          'You will see every shelf holding it, with the shop floor first.',
                    )
                  : results.isEmpty
                  ? EmptyState(
                      Icons.inventory_2_outlined,
                      'Nothing matches "${_vm.query}"',
                      text:
                          'Check the spelling, try the SKU or colour, or scan the tag.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      itemCount: results.length,
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
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
    final c = context.colors;
    final type = Theme.of(context).textTheme;
    final canMove = SessionScope.of(context).can('shelf:putaway');
    final places = _vm.placesOf(w);
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NetImage(url: w.item.imageUrl, width: 72, height: 72, radius: 10),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(w.item.title, style: type.titleMedium),
                    Text(_detail(w.item), style: type.bodySmall),
                    if (w.item.archived) ...[
                      const SizedBox(height: 6),
                      const StatusPill('Archived product', Tone.neutral),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (places.isEmpty)
            Text('None in stock here.', style: type.bodySmall)
          else
            for (final p in places) ...[
              Row(
                children: [
                  Icon(Icons.warehouse_outlined, size: 16, color: c.text),
                  const SizedBox(width: 8),
                  Expanded(child: Text(p.location, style: type.titleSmall)),
                  Text(
                    '${pieces(p.total)} here${p.held > 0 ? ' · ${p.held} held for orders' : ''}',
                    style: type.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final (i, sh) in p.shelves.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _shelfRow(sh, highlight: i == 0 && sh.isShopFloor),
                ),
              if (p.notShelved > 0)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.borderFocus),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'Not shelved',
                                style: type.titleSmall,
                              ),
                              TextSpan(
                                text: p.usesShelves
                                    ? ' · not put on a shelf yet'
                                    : ' · this location has no shelves set up',
                                style: type.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${p.notShelved}',
                        style: type.titleMedium!.copyWith(
                          fontFeatures: _tabular,
                        ),
                      ),
                      if (canMove && p.usesShelves) ...[
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () => AppRoutes.waitingToShelve(
                            context,
                            locationId: p.locationId,
                          ),
                          child: const Text('Put away'),
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 6),
            ],
        ],
      ),
    );
  }

  /// One shelf holding the piece; the first, when it is on the shop floor, stands out.
  Widget _shelfRow(ShelfPlace sh, {required bool highlight}) {
    final c = context.colors;
    return Pressable(
      onTap: () => AppRoutes.spot(context, sh.spotId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: highlight ? tint(c.success, 0.08) : c.input,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: highlight ? tint(c.success, 0.35) : c.border,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: SpotChip(
                address: sh.address,
                name: sh.name,
                colour: sh.colour,
                isShopFloor: sh.isShopFloor,
                big: true,
              ),
            ),
            const SizedBox(width: 12),
            BigQty('${sh.quantity}'),
          ],
        ),
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
      showDragHandle: true,
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
    final c = context.colors;
    final type = Theme.of(context).textTheme;
    final items = _vm.items;
    final error = _vm.error;
    final waiting = _vm.waiting;
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
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
                    : '${pieces(waiting)} in ${widget.locationName}',
              ),
              if (items == null && error != null)
                ErrorView.fromError(
                  error,
                  what: 'the pieces waiting to be put away',
                  onRetry: _vm.load,
                )
              else if (items == null)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Skeleton(height: 76),
                      SizedBox(height: 10),
                      Skeleton(height: 76),
                    ],
                  ),
                )
              else if (items.isEmpty)
                const EmptyState(
                  Icons.task_alt_rounded,
                  'Everything is on a shelf',
                  text:
                      'New stock, returns and transfers into this location will appear here.',
                )
              else
                for (final (i, n) in items.indexed)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: _ItemRow(
                      item: n.item,
                      onTap: SessionScope.of(context).can('shelf:putaway')
                          ? () => _putAway(n)
                          : null,
                      trailing: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          BigQty('${n.notShelved}'),
                          Text(
                            'of ${n.total}',
                            style: type.labelMedium!.copyWith(
                              color: c.textMuted,
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
    final type = Theme.of(context).textTheme;
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _ItemRow(item: widget.item, bare: true),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text('How many?', style: type.titleSmall),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text('To which shelf?', style: type.titleSmall),
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
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: TextField(
                    onChanged: _vm.setFilter,
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Filter shelves',
                      prefixIcon: Icon(Icons.search_rounded, size: 18),
                    ),
                  ),
                ),
                Expanded(
                  child: _vm.loadingSpots
                      ? const Center(child: CircularProgressIndicator())
                      : RadioGroup<String>(
                          groupValue: _vm.offShelf ? '__off__' : to?.id,
                          onChanged: (v) => v == '__off__'
                              ? _vm.takeOffShelf()
                              : _vm.choose(spots.firstWhere((s) => s.id == v)),
                          child: ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            children: [
                              if (!widget.requireTarget)
                                const RadioListTile<String>(
                                  value: '__off__',
                                  title: Text('Off the shelf'),
                                  subtitle: Text('Back to "Not shelved"'),
                                ),
                              for (final s in spots)
                                RadioListTile<String>(
                                  value: s.id,
                                  title: s.name == null
                                      ? ShelfAddress(s.address)
                                      : Text(s.name!),
                                  subtitle: Text(
                                    '${s.address} · ${pieces(s.pieces)} now',
                                  ),
                                ),
                            ],
                          ),
                        ),
                ),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Onto ${widget.fixedTarget!.name ?? widget.fixedTarget!.address}',
                    style: type.bodyMedium!.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
                const Spacer(),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _vm.ready
                        ? () => Navigator.of(context).pop(_vm.result)
                        : null,
                    child: Text(
                      _vm.offShelf
                          ? 'Take ${_vm.qty} off'
                          : (to == null
                                ? 'Choose a shelf'
                                : 'Move ${_vm.qty} to ${to.title}'),
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

/// A piece as a website phone list row: thumbnail, title, detail.
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
    final type = Theme.of(context).textTheme;
    final content = Row(
      children: [
        NetImage(url: item.imageUrl, width: 48, height: 48, radius: 10),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: type.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                _detail(item),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: type.bodySmall,
              ),
              if (item.archived) ...[
                const SizedBox(height: 4),
                const StatusPill('Archived product', Tone.neutral),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
    if (bare) return content;
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: content,
    );
  }
}
