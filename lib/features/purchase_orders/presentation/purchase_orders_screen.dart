import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import 'package:scaleezy/app/app_routes.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/core/utils/money.dart';
import 'package:scaleezy/core/widgets/async_state.dart';
import 'package:scaleezy/core/widgets/scan_sheet.dart';
import 'package:scaleezy/core/widgets/ui.dart';
import 'package:scaleezy/features/purchase_orders/data/purchase_order_models.dart';
import 'package:scaleezy/features/purchase_orders/presentation/view_models/purchase_order_view_model.dart';
import 'package:scaleezy/features/purchase_orders/presentation/view_models/purchase_orders_view_model.dart';
import 'package:scaleezy/features/purchase_orders/presentation/view_models/receive_delivery_view_model.dart';

(Color, Color) _statusColours(String status) => switch (status) {
  'DRAFT' => (AppColors.accentWarning, const Color(0xFFFFFBEB)),
  'SENT' => (AppColors.accentBlue, AppColors.accentBlueLight),
  'PARTIALLY_RECEIVED' => (AppColors.accentPurple, AppColors.accentPurpleLight),
  'RECEIVED' => (AppColors.accentSuccess, AppColors.accentSuccessLight),
  'CANCELLED' => (AppColors.accentDanger, AppColors.accentDangerLight),
  _ => (AppColors.textSecondary, AppColors.bgSurface),
};

Widget _statusChip(String status) {
  final (fg, bg) = _statusColours(status);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      status.replaceAll('_', ' '),
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: fg),
    ),
  );
}

/// "due in 3 days", "due today", "5 days late".
String? _due(PurchaseOrderSummary po) {
  final d = po.expectedDelivery;
  if (d == null || po.status == 'RECEIVED' || po.status == 'CANCELLED') {
    return null;
  }
  final days = DateUtils.dateOnly(
    d,
  ).difference(DateUtils.dateOnly(DateTime.now())).inDays;
  if (days == 0) return 'due today';
  if (days > 0) return 'due in $days ${days == 1 ? 'day' : 'days'}';
  return '${-days} ${days == -1 ? 'day' : 'days'} late';
}

class PurchaseOrdersScreen extends StatefulWidget {
  /// Tests pass their own; otherwise the screen makes and owns one.
  final PurchaseOrdersViewModel? viewModel;

  const PurchaseOrdersScreen({super.key, this.viewModel});

  @override
  State<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends State<PurchaseOrdersScreen> {
  final _date = DateFormat('d MMM');
  late final PurchaseOrdersViewModel _vm =
      widget.viewModel ?? PurchaseOrdersViewModel();

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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => _buildScreen(),
    );
  }

  Widget _buildScreen() {
    final list = _vm.visible;
    final error = _vm.error;

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(
              title: 'Purchase Orders',
              subtitle: _vm.all == null
                  ? null
                  : '${_vm.count('OPEN')} waiting to be received',
            ),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  for (final e in PurchaseOrdersViewModel.filters.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Pressable(
                        onTap: () => _vm.selectFilter(e.key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _vm.filter == e.key
                                ? AppColors.textPrimary
                                : AppColors.bgCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _vm.filter == e.key
                                  ? AppColors.textPrimary
                                  : AppColors.borderLight,
                            ),
                          ),
                          child: Text(
                            '${e.value}  ${_vm.count(e.key)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _vm.filter == e.key
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _vm.all == null && error != null
                  ? ErrorView(message: error, onRetry: _vm.load)
                  : _vm.all == null
                  ? ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        for (var i = 0; i < 5; i++)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: Skeleton(height: 90, radius: 18),
                          ),
                      ],
                    )
                  : list.isEmpty
                  ? ErrorView(
                      message: _vm.filter == 'OPEN'
                          ? 'Nothing is waiting to be received.'
                          : 'No purchase orders here.',
                    )
                  : RefreshIndicator(
                      color: AppColors.accentGold,
                      onRefresh: _vm.load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                        itemCount: list.length,
                        itemBuilder: (_, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _card(list[i]).entrance(i % 15),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(PurchaseOrderSummary po) {
    final due = _due(po);
    final late = due?.contains('late') ?? false;
    return SurfaceCard(
      onTap: () async {
        final changed = await AppRoutes.purchaseOrder(context, po.id);
        if (changed == true) _vm.load();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                po.poNumber,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 8),
              _statusChip(po.status),
              const Spacer(),
              if (po.totalAmount != null)
                Text(
                  formatRupees(po.totalAmount!),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            po.supplierName,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  [
                    '${po.lineCount} ${po.lineCount == 1 ? 'line' : 'lines'}',
                    'ordered ${_date.format(po.createdAt)}',
                    if (po.deliverTo != null) 'to ${po.deliverTo}',
                  ].join(' • '),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              if (due != null)
                Text(
                  due,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: late ? AppColors.accentDanger : AppColors.accentBlue,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class PurchaseOrderScreen extends StatefulWidget {
  final String poId;

  /// Tests pass their own; otherwise the screen makes and owns one.
  final PurchaseOrderViewModel? viewModel;

  const PurchaseOrderScreen({super.key, required this.poId, this.viewModel});

  @override
  State<PurchaseOrderScreen> createState() => _PurchaseOrderScreenState();
}

class _PurchaseOrderScreenState extends State<PurchaseOrderScreen> {
  late final PurchaseOrderViewModel _vm =
      widget.viewModel ?? PurchaseOrderViewModel(widget.poId);

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

  Future<void> _receive() async {
    final done = await AppRoutes.receiveDelivery(context, _vm.po!);
    if (done == true) _vm.deliveryReceived();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => _buildScreen(),
    );
  }

  Widget _buildScreen() {
    final po = _vm.po;
    final error = _vm.error;
    final ordered = _vm.ordered;
    final received = _vm.received;
    final canReceive =
        po != null &&
        po.summary.canReceive &&
        SessionScope.of(context).can('purchase_order:receive');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_vm.changed);
      },
      child: Scaffold(
        backgroundColor: AppColors.bgLight,
        bottomNavigationBar: canReceive
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child:
                      FilledButton.icon(
                        onPressed: _receive,
                        icon: const Icon(Icons.move_to_inbox_rounded),
                        label: const Text(
                          'Receive Now',
                          style: TextStyle(
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
                      ).animate().slideY(
                        begin: 1,
                        end: 0,
                        duration: 400.ms,
                        curve: Curves.easeOutCubic,
                      ),
                ),
              )
            : null,
        body: SafeArea(
          child: RefreshIndicator(
            color: AppColors.accentGold,
            onRefresh: _vm.load,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                PageHeader(
                  title: po?.summary.poNumber ?? 'Purchase order',
                  subtitle: po?.summary.supplierName,
                ),
                if (po == null && error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 80),
                    child: ErrorView(message: error, onRetry: _vm.load),
                  )
                else if (po == null)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Skeleton(height: 260, radius: 22),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _statusChip(po.summary.status),
                              const Spacer(),
                              if (_due(po.summary) != null)
                                Text(
                                  _due(po.summary)!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.accentBlue,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$received',
                                style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                ),
                              ),
                              Text(
                                ' / $ordered pieces received',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(
                                begin: 0,
                                end: ordered == 0 ? 0 : received / ordered,
                              ),
                              duration: const Duration(milliseconds: 900),
                              curve: Curves.easeOutCubic,
                              builder: (_, v, _) => LinearProgressIndicator(
                                value: v,
                                minHeight: 10,
                                backgroundColor: AppColors.bgSurface,
                                color: AppColors.accentSuccess,
                              ),
                            ),
                          ),
                          if (po.summary.totalAmount != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Order value ${formatRupees(po.summary.totalAmount!)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          if (po.summary.deliverTo != null)
                            Text(
                              'Deliver to ${po.summary.deliverTo}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          if (po.notes != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              po.notes!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ).entrance(0),
                  ),
                  const SizedBox(height: 20),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: SectionHeader(title: 'Lines'),
                  ),
                  for (final (i, l) in po.lines.indexed)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: SurfaceCard(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        [
                                          l.sku,
                                          ?l.color,
                                          if (l.size != null) 'Size ${l.size}',
                                        ].join(' • '),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${l.received}/${l.ordered}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: l.outstanding == 0
                                        ? AppColors.accentSuccess
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: l.ordered == 0
                                    ? 0
                                    : l.received / l.ordered,
                                minHeight: 5,
                                backgroundColor: AppColors.bgSurface,
                                color: AppColors.accentSuccess,
                              ),
                            ),
                            if (l.unitPrice != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                '${formatRupees(l.unitPrice!)} each',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ).entrance(1 + i),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ReceiveDeliveryScreen extends StatefulWidget {
  final PurchaseOrderDetail po;

  /// Tests pass their own; otherwise the screen makes and owns one.
  final ReceiveDeliveryViewModel? viewModel;

  const ReceiveDeliveryScreen({super.key, required this.po, this.viewModel});

  @override
  State<ReceiveDeliveryScreen> createState() => _ReceiveDeliveryScreenState();
}

class _ReceiveDeliveryScreenState extends State<ReceiveDeliveryScreen> {
  late final ReceiveDeliveryViewModel _vm =
      widget.viewModel ?? ReceiveDeliveryViewModel(widget.po);
  late final _receivedBy = TextEditingController(
    text: SessionScope.read(context).user?.name ?? '',
  );
  final _reference = TextEditingController();

  @override
  void dispose() {
    _receivedBy.dispose();
    _reference.dispose();
    if (widget.viewModel == null) _vm.dispose();
    super.dispose();
  }

  /// Each scan of a piece's tag counts one against its line.
  Future<void> _scanPieces() async {
    await showScanSheet(
      context,
      title: 'Scan each piece',
      hint: 'One scan = one piece',
      onCode: (code) async => _vm.scan(code),
    );
  }

  Future<void> _submit() async {
    if (_vm.validate(_receivedBy.text) != null) return;
    final lines = _vm.countedLines;
    final ok = await confirmAction(
      context,
      title: 'Add ${_vm.total} pieces to stock?',
      message:
          '$lines ${lines == 1 ? 'line' : 'lines'} of ${widget.po.summary.poNumber} from ${widget.po.summary.supplierName}'
          '${widget.po.summary.deliverTo != null ? ' into ${widget.po.summary.deliverTo}' : ''}. '
          'This updates stock straight away.',
      confirmLabel: 'Receive Now',
    );
    if (!ok || !mounted) return;

    final error = await _vm.receive(
      receivedBy: _receivedBy.text,
      reference: _reference.text,
    );
    if (!mounted) return;
    if (error != null) {
      showMessage(context, error, error: true);
      return;
    }
    showMessage(context, 'Received ${_vm.total} pieces.', success: true);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => _buildScreen(),
    );
  }

  Widget _buildScreen() {
    final outstanding = _vm.outstanding;
    final total = _vm.total;
    final error = _vm.error;
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.accentDanger,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _vm.busy ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentGold,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _vm.busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          total == 0
                              ? 'Count the pieces'
                              : 'Receive $total pieces',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            PageHeader(
              title: 'Receive Now',
              subtitle:
                  '${widget.po.summary.poNumber} • $outstanding pieces outstanding',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _scanPieces,
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: const Text(
                        'Scan pieces',
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
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _vm.allArrived,
                      icon: const Icon(Icons.done_all_rounded),
                      label: const Text(
                        'All arrived',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.borderLight),
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
            const SizedBox(height: 14),
            for (final (i, l) in _vm.lines.indexed)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _vm.qty(l.id) == l.outstanding
                        ? AppColors.accentSuccessLight
                        : AppColors.bgCard,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: _vm.qty(l.id) == l.outstanding
                          ? AppColors.accentSuccess.withValues(alpha: 0.3)
                          : AppColors.borderLight,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              [
                                l.sku,
                                ?l.color,
                                if (l.size != null) 'Size ${l.size}',
                              ].join(' • '),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                            Text(
                              '${l.outstanding} still to come',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accentBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                      QuantityStepper(
                        value: _vm.qty(l.id),
                        max: l.outstanding,
                        onChanged: (v) => _vm.setQty(l.id, v),
                      ),
                    ],
                  ),
                ).entrance(i % 12),
              ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  TextField(
                    controller: _receivedBy,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Received by',
                      hintText: 'Name of the person who took the goods',
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                      filled: true,
                      fillColor: AppColors.bgCard,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _reference,
                    decoration: InputDecoration(
                      labelText: 'Supplier invoice / challan no. (optional)',
                      hintText: 'e.g. INV-2291',
                      prefixIcon: const Icon(Icons.receipt_long_outlined),
                      filled: true,
                      fillColor: AppColors.bgCard,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
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
