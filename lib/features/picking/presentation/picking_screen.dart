import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:scaleezy/app/app_routes.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/shop/shop_context.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/core/widgets/async_state.dart';
import 'package:scaleezy/core/widgets/scan_sheet.dart';
import 'package:scaleezy/core/widgets/ui.dart';
import 'package:scaleezy/features/picking/data/picking_models.dart';
import 'package:scaleezy/features/picking/presentation/view_models/pick_orders_view_model.dart';
import 'package:scaleezy/features/picking/presentation/view_models/pick_walk_view_model.dart';
import 'package:scaleezy/features/shelves/presentation/widgets/shelf_bits.dart';

String _plural(int n, String one, String many) => '$n ${n == 1 ? one : many}';

const _tabular = [FontFeature.tabularFigures()];

// ---- Orders waiting to go out ---------------------------------------------------------------------

/// The website's `PickList`: the selected store's orders waiting to go out, to pick together.
class PickOrdersScreen extends StatefulWidget {
  /// Tests pass their own; otherwise the screen makes and owns one.
  final PickOrdersViewModel? viewModel;

  const PickOrdersScreen({super.key, this.viewModel});

  @override
  State<PickOrdersScreen> createState() => _PickOrdersScreenState();
}

class _PickOrdersScreenState extends State<PickOrdersScreen> {
  late final PickOrdersViewModel _vm =
      widget.viewModel ?? PickOrdersViewModel();
  final _date = DateFormat('d MMM');
  (int, String?)? _seen;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The app's one store; switching it (or the shop loading it) lists that store's orders.
    final shop = ShopScope.of(context);
    final seen = (shop.revision, shop.selectedLocation?.id);
    if (seen != _seen) {
      _seen = seen;
      _vm.show(shop.selectedLocation);
    }
  }

  @override
  void dispose() {
    if (widget.viewModel == null) _vm.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final sent = await AppRoutes.pickWalk(context, orderIds: _vm.selected);
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
    final error = _vm.error;
    final chosen = _vm.selected.length;
    return Scaffold(
      bottomNavigationBar: orders == null || orders.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  onPressed: chosen == 0 ? null : _pick,
                  icon: const Icon(Icons.route_rounded),
                  label: Text(
                    chosen == 0
                        ? 'Choose the orders to pick'
                        : 'Pick ${_plural(chosen, 'order', 'orders')}',
                  ),
                ),
              ),
            ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _vm.load,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              const PageHeader(
                title: 'Pick',
                subtitle:
                    'Choose the orders to send out and walk the shelves once to collect them.',
              ),
              if (_vm.location == null)
                const EmptyState(
                  Icons.place_outlined,
                  'No store is set up yet, so there are no orders to pick.',
                )
              else if (orders == null && error != null)
                ErrorView.fromError(
                  error,
                  what: 'the orders to pick',
                  onRetry: _vm.load,
                )
              else if (orders == null)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      Skeleton(height: 72),
                      SizedBox(height: 10),
                      Skeleton(height: 72),
                      SizedBox(height: 10),
                      Skeleton(height: 72),
                    ],
                  ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: SectionHeader(
                    title: 'Waiting to go out from ${_vm.location!.name}',
                    trailing: orders.isEmpty
                        ? null
                        : chosen > 0
                        ? 'Clear'
                        : 'Select ${orders.length.clamp(0, PickOrdersViewModel.maxOrders)}',
                    onTrailing: _vm.selectAllOrClear,
                  ),
                ),
                if (orders.isEmpty)
                  const EmptyState(
                    Icons.check_circle_outline_rounded,
                    'Nothing waiting to go out',
                    text:
                        'Confirmed orders with pieces still to send appear here.',
                  )
                else
                  for (final (i, o) in orders.indexed)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
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
    final c = context.colors;
    final type = Theme.of(context).textTheme;
    final sel = _vm.isSelected(o.id);
    return Pressable(
      onTap: () => _vm.toggle(o.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: const Cubic(0.16, 1, 0.3, 1),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: sel ? c.hover : c.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? c.borderFocus : c.border),
        ),
        child: Row(
          children: [
            Icon(
              sel
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: sel ? c.success : c.textMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: o.orderNumber, style: type.titleSmall),
                        TextSpan(
                          text:
                              ' · ${o.customer ?? 'Customer'} · ${o.channelName}',
                          style: type.bodySmall,
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      _date.format(o.createdAt),
                      _plural(o.lines, 'line', 'lines'),
                      if (o.partlySent) 'partly sent',
                    ].join(' · '),
                    style: type.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            BigQty('${o.pieces}'),
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
    final c = context.colors;
    final type = Theme.of(context).textTheme;
    final list = _vm.list;
    final error = _vm.error;
    if (list == null) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const PageHeader(title: 'Pick'),
              Expanded(
                child: error != null
                    ? ErrorView.fromError(
                        error,
                        what: 'the pick list',
                        onRetry: _vm.load,
                      )
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
      bottomNavigationBar: _bottomBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            PageHeader(
              title: 'Pick',
              subtitle:
                  '${pieces(list.pieces)} for ${_plural(list.orders.length, 'order', 'orders')}',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$done of ${tasks.length} picked',
                      style: type.titleMedium!.copyWith(fontFeatures: _tabular),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(
                          end: tasks.isEmpty ? 0 : done / tasks.length,
                        ),
                        duration: const Duration(milliseconds: 200),
                        builder: (_, v, _) => LinearProgressIndicator(
                          value: v,
                          minHeight: 6,
                          backgroundColor: c.input,
                          color: c.success,
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
                      style: type.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: current == null ? null : _scan,
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: const Text('Scan shelf or piece'),
                      ),
                    ),
                  ],
                ),
              ).entrance(0),
            ),
            if (list.short.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: SurfaceCard(
                  padding: EdgeInsets.zero,
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 4,
                          decoration: BoxDecoration(
                            color: c.danger,
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(12),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Not enough here', style: type.titleSmall),
                                for (final s in list.short)
                                  Text(
                                    '${s.orderNumber}: ${s.quantity} × ${s.item.title} (${s.item.sku})',
                                    style: type.bodySmall,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ).entrance(1),
              ),
            const SizedBox(height: 14),
            for (final (i, s) in stops.indexed)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: _stopCard(i + 1, s).entrance(2 + i),
              ),
            if (list.notShelved.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SurfaceCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NOT ON A SHELF — FIND THESE IN THE LOCATION',
                        style: type.labelSmall!.copyWith(color: c.textMuted),
                      ),
                      for (final p in list.notShelved) ...[
                        const SizedBox(height: 10),
                        _row(_vm.task('loose|${p.salesOrderItemId}')!),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _stopCard(int n, PickStop s) {
    final c = context.colors;
    final keys = [for (final p in s.picks) '${s.spotId}|${p.salesOrderItemId}'];
    final finished = keys.every((k) => _vm.isDone(_vm.task(k)!));
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: finished ? 0.55 : 1,
      child: SurfaceCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.input,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$n',
                    style: Theme.of(context).textTheme.labelMedium!.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SpotChip(
                    address: s.address,
                    name: s.name,
                    colour: s.colour,
                    isShopFloor: s.isShopFloor,
                    big: true,
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
    final c = context.colors;
    final type = Theme.of(context).textTheme;
    final got = _vm.picked(t);
    final missing = _vm.missing(t);
    final done = _vm.isDone(t);
    final item = t.pick.item;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: done ? tint(c.success, 0.08) : c.input,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
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
                    Text(
                      '${item.detail} · ${t.pick.orderNumber}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: type.bodySmall,
                    ),
                    if (missing > 0)
                      Text(
                        '$missing not found — reported',
                        style: type.bodySmall!.copyWith(color: c.danger),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              BigQty('$got/${t.pick.quantity}'),
              if (done) ...[
                const SizedBox(width: 6),
                Icon(Icons.check_circle_rounded, size: 22, color: c.success),
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
                      if (t.stop != null) ...[
                        OutlinedButton.icon(
                          onPressed: _vm.reporting ? null : () => _notHere(t),
                          icon: const Icon(
                            Icons.report_gmailerrorred_rounded,
                            size: 16,
                          ),
                          label: const Text('Not here'),
                        ),
                        const SizedBox(width: 6),
                      ],
                      FilledButton(
                        onPressed: () => _vm.pickAll(t),
                        child: const Text('Picked'),
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
    final c = context.colors;
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
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: c.card,
          border: Border(top: BorderSide(color: c.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              canSend
                  ? status
                  : '$status Someone who can send orders out finishes this.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (canSend) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: ready == 0 || _vm.sending ? null : _sendOut,
                  icon: _vm.sending
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: c.card,
                          ),
                        )
                      : const Icon(Icons.local_shipping_rounded),
                  label: Text(
                    ready == 0
                        ? 'Send out picked'
                        : 'Send out ${pieces(ready)}',
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
