import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:scaleezy/app/app_routes.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/shop/shop_context.dart';
import 'package:scaleezy/core/shop/shop_models.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/core/widgets/async_state.dart';
import 'package:scaleezy/core/widgets/scan_sheet.dart';
import 'package:scaleezy/core/widgets/ui.dart';
import 'package:scaleezy/features/picking/data/picking_models.dart';
import 'package:scaleezy/features/picking/presentation/view_models/pick_orders_view_model.dart';
import 'package:scaleezy/features/picking/presentation/view_models/pick_walk_view_model.dart';

String _plural(int n, String one, String many) => '$n ${n == 1 ? one : many}';

// ---- Orders waiting to go out ---------------------------------------------------------------------

class PickOrdersScreen extends StatefulWidget {
  /// The store to pick in; otherwise the selected store, else the first that is not online.
  final StockLocation? location;

  /// Tests pass their own; otherwise the screen makes and owns one.
  final PickOrdersViewModel? viewModel;

  const PickOrdersScreen({super.key, this.location, this.viewModel});

  @override
  State<PickOrdersScreen> createState() => _PickOrdersScreenState();
}

class _PickOrdersScreenState extends State<PickOrdersScreen> {
  late final PickOrdersViewModel _vm =
      widget.viewModel ?? PickOrdersViewModel();
  final _date = DateFormat('d MMM');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Until a store is known, try again whenever the shop's stores change.
    if (_vm.location == null) {
      final shop = ShopScope.of(context);
      _vm.start(widget.location ?? shop.selectedLocation, shop.locations);
    }
  }

  @override
  void dispose() {
    if (widget.viewModel == null) _vm.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final sent = await AppRoutes.pickWalk(
      context,
      locationId: _vm.location!.id,
      orderIds: _vm.selected,
    );
    if (sent == true) _vm.clearSelection();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => _buildScreen(),
    );
  }

  Widget _buildScreen() {
    final orders = _vm.orders;
    final chosen = _vm.selected.length;
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      bottomNavigationBar: orders == null || orders.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: FilledButton.icon(
                  onPressed: chosen == 0 ? null : _pick,
                  icon: const Icon(Icons.route_rounded),
                  label: Text(
                    chosen == 0
                        ? 'Choose the orders to pick'
                        : 'Pick ${_plural(chosen, 'order', 'orders')}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentGold,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accentGold,
          onRefresh: _vm.load,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              PageHeader(title: 'Pick orders', subtitle: _vm.location?.name),
              if (orders == null && _vm.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: ErrorView(message: _vm.error!, onRetry: _vm.load),
                )
              else if (orders == null)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      Skeleton(height: 76, radius: 18),
                      SizedBox(height: 8),
                      Skeleton(height: 76, radius: 18),
                      SizedBox(height: 8),
                      Skeleton(height: 76, radius: 18),
                    ],
                  ),
                )
              else if (orders.isEmpty)
                const _Empty(
                  icon: Icons.check_circle_outline_rounded,
                  title: 'Nothing waiting to go out',
                  text:
                      'Confirmed orders with pieces still to send appear here.',
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: SectionHeader(
                    title: 'Waiting to go out',
                    trailing: chosen > 0
                        ? 'Clear'
                        : 'Select ${orders.length.clamp(0, PickOrdersViewModel.maxOrders)}',
                    onTrailing: _vm.selectAllOrClear,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Text(
                    'Choose the orders to send out, then walk the shelves once to collect them.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                for (final (i, o) in orders.indexed)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: _orderRow(o).entrance(i),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _orderRow(PickOrder o) {
    final sel = _vm.isSelected(o.id);
    return Pressable(
      onTap: () => _vm.toggle(o.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: sel ? AppColors.accentGoldLight : AppColors.bgCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: sel ? AppColors.accentGoldBorder : AppColors.borderLight,
          ),
        ),
        child: Row(
          children: [
            Icon(
              sel
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: sel ? AppColors.accentSuccess : AppColors.textMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    o.orderNumber,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${o.customer ?? 'Customer'} • ${o.channelName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    [
                      _date.format(o.createdAt),
                      _plural(o.lines, 'line', 'lines'),
                      if (o.partlySent) 'partly sent',
                    ].join(' • '),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Text(
                  '${o.pieces}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  o.pieces == 1 ? 'piece' : 'pieces',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---- The walk -------------------------------------------------------------------------------------

class PickWalkScreen extends StatefulWidget {
  final String locationId;
  final List<String> orderIds;

  /// Tests pass their own; otherwise the screen makes and owns one.
  final PickWalkViewModel? viewModel;

  const PickWalkScreen({
    super.key,
    required this.locationId,
    required this.orderIds,
    this.viewModel,
  });

  @override
  State<PickWalkScreen> createState() => _PickWalkScreenState();
}

class _PickWalkScreenState extends State<PickWalkScreen> {
  late final PickWalkViewModel _vm =
      widget.viewModel ??
      PickWalkViewModel(
        locationId: widget.locationId,
        orderIds: widget.orderIds,
      );

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

  Future<void> _scan() => showScanSheet(
    context,
    title: 'Scan the shelf or the piece',
    hint: 'Shelf label first, then each piece',
    onCode: (code) async => _vm.scan(code),
  );

  Future<void> _notHere(PickTask t) async {
    final gone = t.pick.quantity - _vm.picked(t) - _vm.missing(t);
    final ok = await confirmAction(
      context,
      title: 'Not on the shelf?',
      message:
          '${_plural(gone, 'piece', 'pieces')} of ${t.pick.item.title} not found on ${t.stop!.address}. '
          'Someone will be asked to count that shelf. What you found is kept.',
      confirmLabel: 'Report',
      danger: true,
    );
    if (!ok || !mounted) return;
    final error = await _vm.reportNotFound(t);
    if (!mounted) return;
    showMessage(
      context,
      error ?? 'Recorded. Someone will count that shelf.',
      error: error != null,
      success: error == null,
    );
  }

  Future<void> _sendOut() async {
    final ok = await confirmAction(
      context,
      title: 'Send out ${_plural(_vm.readyPieces, 'piece', 'pieces')}?',
      message:
          'For ${_plural(_vm.readyOrders, 'order', 'orders')}. Stock goes down and the orders are marked sent straight away.',
      confirmLabel: 'Send out',
    );
    if (!ok || !mounted) return;
    final result = await _vm.sendOut();
    if (result == null || !mounted) return;
    if (result.sent > 0) {
      showMessage(
        context,
        '${_plural(result.sent, 'order', 'orders')} sent out.',
        success: true,
      );
    }
    for (final p in result.problems) {
      showMessage(context, p, error: true);
    }
    if (result.sent > 0) Navigator.of(context).pop(true);
  }

  Future<void> _leave() async {
    final ok = await confirmAction(
      context,
      title: 'Leave this pick?',
      message:
          'The pieces you picked are not sent out yet. Leaving forgets what you ticked off.',
      confirmLabel: 'Leave',
      danger: true,
    );
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => PopScope(
        canPop: _vm.readyPieces == 0 || _vm.sending,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _leave();
        },
        child: _buildScreen(),
      ),
    );
  }

  Widget _buildScreen() {
    final list = _vm.list;
    if (list == null) {
      return Scaffold(
        backgroundColor: AppColors.bgLight,
        body: SafeArea(
          child: Column(
            children: [
              const PageHeader(title: 'Pick'),
              Expanded(
                child: _vm.error != null
                    ? ErrorView(message: _vm.error!, onRetry: _vm.load)
                    : const LoadingView(message: 'Working out the walk…'),
              ),
            ],
          ),
        ),
      );
    }
    final tasks = _vm.tasks;
    final done = _vm.doneCount;
    final current = _vm.current;
    final stops = list.stops;
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      bottomNavigationBar: _bottomBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            PageHeader(
              title: 'Pick',
              subtitle:
                  '${_plural(list.pieces, 'piece', 'pieces')} for ${_plural(list.orders.length, 'order', 'orders')}',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$done of ${tasks.length} picked',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(
                          end: tasks.isEmpty ? 0 : done / tasks.length,
                        ),
                        duration: const Duration(milliseconds: 300),
                        builder: (_, v, _) => LinearProgressIndicator(
                          value: v,
                          minHeight: 6,
                          backgroundColor: AppColors.bgSurface,
                          color: AppColors.accentSuccess,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      current == null
                          ? 'All picked.'
                          : current.stop != null
                          ? 'Next: go to ${current.stop!.address}, then scan the item.'
                          : 'Next: find ${current.pick.item.title} off the shelves.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: current == null ? null : _scan,
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: const Text(
                          'Scan shelf or piece',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.accentGold,
                          side: const BorderSide(
                            color: AppColors.accentGoldBorder,
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
              ).entrance(0),
            ),
            if (list.short.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.accentDangerLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.accentDanger.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Not enough here',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.accentDanger,
                        ),
                      ),
                      for (final s in list.short)
                        Text(
                          '${s.orderNumber}: ${s.quantity} × ${s.item.title} (${s.item.sku})',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ).entrance(1),
              ),
            const SizedBox(height: 18),
            for (final (i, s) in stops.indexed)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: _stopCard(i + 1, s).entrance(2 + i),
              ),
            if (list.notShelved.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: SectionHeader(
                  title: 'Not on a shelf — find these in the store',
                ),
              ),
              for (final p in list.notShelved)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: _row(_vm.task('loose|${p.salesOrderItemId}')!),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stopCard(int n, PickStop s) {
    final keys = [for (final p in s.picks) '${s.spotId}|${p.salesOrderItemId}'];
    final finished = keys.every((k) => _vm.isDone(_vm.task(k)!));
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: finished ? 0.55 : 1,
      child: SurfaceCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.bgSurface,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$n',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 10),
                if (s.colour != null) ...[
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Color(s.colour!),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
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
                      if (s.name != null)
                        Text(
                          s.name!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: s.isShopFloor
                        ? AppColors.accentGoldLight
                        : AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    s.isShopFloor ? 'Shop floor' : 'Back room',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: s.isShopFloor
                          ? AppColors.accentGold
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            for (final k in keys) ...[
              const SizedBox(height: 10),
              _row(_vm.task(k)!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(PickTask t) {
    final got = _vm.picked(t);
    final missing = _vm.missing(t);
    final done = _vm.isDone(t);
    final item = t.pick.item;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: done ? AppColors.accentSuccessLight : AppColors.bgSurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              NetImage(url: item.imageUrl, width: 48, height: 48, radius: 12),
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
                    Text(
                      '${item.detail} • ${t.pick.orderNumber}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (missing > 0)
                      Text(
                        '$missing not found — reported',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.accentDanger,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '$got/${t.pick.quantity}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (done) ...[
                const SizedBox(width: 6),
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.accentSuccess,
                ),
              ],
            ],
          ),
          if (missing == 0) ...[
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                QuantityStepper(
                  value: got,
                  max: t.pick.quantity,
                  onChanged: (v) => _vm.setPicked(t, v),
                ),
                if (!done)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (t.stop != null)
                        TextButton.icon(
                          onPressed: _vm.reporting ? null : () => _notHere(t),
                          icon: const Icon(
                            Icons.report_gmailerrorred_rounded,
                            size: 18,
                          ),
                          label: const Text('Not here'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.accentDanger,
                          ),
                        ),
                      FilledButton(
                        onPressed: () => _vm.pickAll(t),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accentGold,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Picked',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _bottomBar() {
    final tasks = _vm.tasks;
    final ready = _vm.readyPieces;
    final canSend = SessionScope.of(context).can('dispatch:create');
    final status = tasks.isEmpty
        ? 'None of these pieces are in this store.'
        : _vm.allDone
        ? (ready > 0
              ? 'Everything is picked.'
              : 'Nothing was found to send out.')
        : '${tasks.length - _vm.doneCount} still to pick. You can send out what is picked.';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              canSend
                  ? status
                  : '$status Someone who can send orders out finishes this.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (canSend) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: ready == 0 || _vm.sending ? null : _sendOut,
                  icon: _vm.sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.local_shipping_rounded),
                  label: Text(
                    ready == 0
                        ? 'Send out picked'
                        : 'Send out ${_plural(ready, 'piece', 'pieces')}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentGold,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  const _Empty({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(32, 60, 32, 32),
    child: Column(
      children: [
        Icon(
          icon,
          size: 52,
          color: AppColors.accentGold.withValues(alpha: 0.4),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ],
    ),
  );
}
