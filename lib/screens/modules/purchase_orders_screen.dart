import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../api/api_client.dart';
import '../../api/auth_session.dart';
import '../../api/module_repository.dart';
import '../../models/module_models.dart';
import '../../theme/app_theme.dart';
import '../../utils/money.dart';
import '../../widgets/async_state.dart';
import '../../widgets/scan_sheet.dart';
import '../../widgets/ui.dart';

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
  const PurchaseOrdersScreen({super.key});

  @override
  State<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends State<PurchaseOrdersScreen> {
  final _date = DateFormat('d MMM');
  List<PurchaseOrderSummary>? _all;
  String? _error;
  String _filter = 'OPEN';

  static const _filters = {
    'OPEN': 'To receive',
    'DRAFT': 'Draft',
    'RECEIVED': 'Received',
    'CANCELLED': 'Cancelled',
    'ALL': 'All',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final list = await ModuleRepository().purchaseOrders();
      if (mounted) setState(() => _all = list);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  bool _matches(PurchaseOrderSummary po, String f) => switch (f) {
    'OPEN' => po.canReceive,
    'ALL' => true,
    _ => po.status == f,
  };

  @override
  Widget build(BuildContext context) {
    final all = _all ?? const <PurchaseOrderSummary>[];
    final list = all.where((po) => _matches(po, _filter)).toList();

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(
              title: 'Purchase Orders',
              subtitle: _all == null
                  ? null
                  : '${all.where((p) => p.canReceive).length} waiting to be received',
            ),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  for (final e in _filters.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Pressable(
                        onTap: () => setState(() => _filter = e.key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _filter == e.key
                                ? AppColors.textPrimary
                                : AppColors.bgCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _filter == e.key
                                  ? AppColors.textPrimary
                                  : AppColors.borderLight,
                            ),
                          ),
                          child: Text(
                            '${e.value}  ${all.where((p) => _matches(p, e.key)).length}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _filter == e.key
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
              child: _all == null && _error != null
                  ? ErrorView(message: _error!, onRetry: _load)
                  : _all == null
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
                      message: _filter == 'OPEN'
                          ? 'Nothing is waiting to be received.'
                          : 'No purchase orders here.',
                    )
                  : RefreshIndicator(
                      color: AppColors.accentGold,
                      onRefresh: _load,
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
        final changed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => PurchaseOrderScreen(poId: po.id)),
        );
        if (changed == true) _load();
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
  const PurchaseOrderScreen({super.key, required this.poId});

  @override
  State<PurchaseOrderScreen> createState() => _PurchaseOrderScreenState();
}

class _PurchaseOrderScreenState extends State<PurchaseOrderScreen> {
  PurchaseOrderDetail? _po;
  String? _error;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final po = await ModuleRepository().purchaseOrder(widget.poId);
      if (mounted) setState(() => _po = po);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _receive() async {
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ReceiveDeliveryScreen(po: _po!)),
    );
    if (done == true) {
      _changed = true;
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final po = _po;
    final ordered = po?.lines.fold<int>(0, (a, l) => a + l.ordered) ?? 0;
    final received = po?.lines.fold<int>(0, (a, l) => a + l.received) ?? 0;
    final canReceive =
        po != null &&
        po.summary.canReceive &&
        SessionScope.of(context).can('purchase_order:receive');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
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
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                PageHeader(
                  title: po?.summary.poNumber ?? 'Purchase order',
                  subtitle: po?.summary.supplierName,
                ),
                if (po == null && _error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 80),
                    child: ErrorView(message: _error!, onRetry: _load),
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
  const ReceiveDeliveryScreen({super.key, required this.po});

  @override
  State<ReceiveDeliveryScreen> createState() => _ReceiveDeliveryScreenState();
}

class _ReceiveDeliveryScreenState extends State<ReceiveDeliveryScreen> {
  late final List<PurchaseOrderLine> _lines = widget.po.lines
      .where((l) => l.outstanding > 0)
      .toList();
  late final Map<String, int> _qty = {for (final l in _lines) l.id: 0};
  late final _receivedBy = TextEditingController(
    text: SessionScope.read(context).user?.name ?? '',
  );
  final _reference = TextEditingController();
  // One key for this delivery: if a slow submit is retried, the server counts it once.
  final _requestKey = ModuleRepository.newRequestKey();
  bool _busy = false;
  String? _error;

  int get _total => _qty.values.fold(0, (a, b) => a + b);

  @override
  void dispose() {
    _receivedBy.dispose();
    _reference.dispose();
    super.dispose();
  }

  /// Each scan of a piece's tag counts one against its line.
  Future<void> _scanPieces() async {
    await showScanSheet(
      context,
      title: 'Scan each piece',
      hint: 'One scan = one piece',
      onCode: (code) async {
        final line = _lines
            .where((l) => l.barcode == code || l.sku == code)
            .firstOrNull;
        if (line == null) return 'Not on this order: $code';
        final now = _qty[line.id]!;
        if (now >= line.outstanding) {
          return 'All ${line.outstanding} of ${line.title} already counted';
        }
        setState(() => _qty[line.id] = now + 1);
        return '+1  ${line.title}  (${now + 1}/${line.outstanding})';
      },
    );
  }

  Future<void> _submit() async {
    if (_total == 0) {
      setState(() => _error = 'Count at least one piece first.');
      return;
    }
    if (_receivedBy.text.trim().length < 2) {
      setState(
        () => _error = 'Enter the name of the person who received the goods.',
      );
      return;
    }
    final lines = _lines.where((l) => _qty[l.id]! > 0).length;
    final ok = await confirmAction(
      context,
      title: 'Add $_total pieces to stock?',
      message:
          '$lines ${lines == 1 ? 'line' : 'lines'} of ${widget.po.summary.poNumber} from ${widget.po.summary.supplierName}'
          '${widget.po.summary.deliverTo != null ? ' into ${widget.po.summary.deliverTo}' : ''}. '
          'This updates stock straight away.',
      confirmLabel: 'Receive Now',
    );
    if (!ok || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ModuleRepository().receivePurchaseOrder(
        widget.po.summary.id,
        quantities: _qty,
        receivedByName: _receivedBy.text,
        supplierReference: _reference.text,
        requestKey: _requestKey,
      );
      if (!mounted) return;
      showMessage(context, 'Received $_total pieces.', success: true);
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final outstanding = _lines.fold<int>(0, (a, l) => a + l.outstanding);
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
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
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentGold,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _total == 0
                              ? 'Count the pieces'
                              : 'Receive $_total pieces',
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
                      onPressed: () => setState(() {
                        for (final l in _lines) {
                          _qty[l.id] = l.outstanding;
                        }
                      }),
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
            for (final (i, l) in _lines.indexed)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _qty[l.id]! == l.outstanding
                        ? AppColors.accentSuccessLight
                        : AppColors.bgCard,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: _qty[l.id]! == l.outstanding
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
                        value: _qty[l.id]!,
                        max: l.outstanding,
                        onChanged: (v) => setState(() => _qty[l.id] = v),
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
