import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:scaleezy/app/app_routes.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/shop/shop_context.dart';
import 'package:scaleezy/core/shop/shop_models.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/core/utils/labels.dart';
import 'package:scaleezy/core/widgets/async_state.dart';
import 'package:scaleezy/core/widgets/scan_sheet.dart';
import 'package:scaleezy/core/widgets/status_pill.dart';
import 'package:scaleezy/core/widgets/ui.dart';
import 'package:scaleezy/features/stock_counts/data/stock_count_models.dart';
import 'package:scaleezy/features/stock_counts/presentation/view_models/stock_count_view_model.dart';
import 'package:scaleezy/features/stock_counts/presentation/view_models/stock_counts_view_model.dart';

final _date = DateFormat('d MMM');

String _lines(int n) => '$n ${n == 1 ? 'line' : 'lines'}';

/// The list answers only the store's id; its name comes from the shop's stores.
String? _storeName(BuildContext context, String? id) =>
    ShopScope.of(context).locations.where((l) => l.id == id).firstOrNull?.name;

Widget _statusPill(String status) {
  final look = describeStatus(stockCountStatuses, status);
  return StatusPill(look.label, look.tone);
}

/// The web's rule: 95% or better reads as good.
Color _accuracyColour(BuildContext context, double accuracy) =>
    accuracy >= 95 ? context.colors.success : context.colors.danger;

Widget _busyLabel(BuildContext context, bool busy, String label) => busy
    ? SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: context.colors.card,
        ),
      )
    : Text(label);

/// Every stock count, newest first, and starting a new one.
class StockCountsScreen extends StatefulWidget {
  /// Tests pass their own; otherwise the screen makes and owns one.
  final StockCountsViewModel? viewModel;

  const StockCountsScreen({super.key, this.viewModel});

  @override
  State<StockCountsScreen> createState() => _StockCountsScreenState();
}

class _StockCountsScreenState extends State<StockCountsScreen> {
  late final StockCountsViewModel _vm =
      widget.viewModel ?? StockCountsViewModel();

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

  Future<void> _new() async {
    // The count is of the store the whole app is on, as the web's New Audit.
    final store = ShopScope.read(context).selectedLocation;
    final created = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => _NewCountSheet(vm: _vm, store: store),
    );
    if (created == true && mounted) _open(_vm.created!.id);
  }

  Future<void> _open(String id) async {
    await AppRoutes.stockCount(context, id);
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
    final list = _vm.counts;
    final error = _vm.error;
    return Scaffold(
      floatingActionButton: SessionScope.of(context).can('stock_count:create')
          ? FloatingActionButton.extended(
              onPressed: _new,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New count'),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(
              title: 'Stock count',
              subtitle: list == null ? null : '${_vm.openCount} still open',
            ),
            Expanded(
              child: list == null && error != null
                  ? ErrorView.fromError(
                      error,
                      what: 'audits',
                      onRetry: _vm.load,
                    )
                  : list == null
                  ? ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        for (var i = 0; i < 5; i++)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: Skeleton(height: 90, radius: 12),
                          ),
                      ],
                    )
                  : list.isEmpty
                  ? const EmptyState(
                      Icons.assignment_outlined,
                      'No audits found',
                      text:
                          'Start your first stock count to ensure inventory accuracy.',
                    )
                  : RefreshIndicator(
                      onRefresh: _vm.load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
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

  Widget _card(StockCount c) {
    final type = Theme.of(context).textTheme;
    final counted = c.countedItems;
    final accuracy = c.accuracy;
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      onTap: () => _open(c.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(c.name, style: type.titleSmall)),
              const SizedBox(width: 8),
              _statusPill(c.status),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            [
              ?_storeName(context, c.locationId),
              'made ${_date.format(c.createdAt)}',
            ].join(' • '),
            style: type.labelMedium!.copyWith(color: context.colors.textMuted),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  counted != null
                      ? '$counted of ${c.itemCount} counted'
                      : '${c.itemCount} ${c.itemCount == 1 ? 'item' : 'items'}${c.isOpen ? ' to count' : ''}',
                  style: type.bodySmall,
                ),
              ),
              if (accuracy != null)
                Text(
                  '${accuracy.toStringAsFixed(1)}% matched',
                  style: type.labelMedium!.copyWith(
                    color: _accuracyColour(context, accuracy),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Name and (optionally) one category; the store is the one the app is on. The draft stays
/// here; the list's view model makes the count.
class _NewCountSheet extends StatefulWidget {
  final StockCountsViewModel vm;
  final StockLocation? store;

  const _NewCountSheet({required this.vm, required this.store});

  @override
  State<_NewCountSheet> createState() => _NewCountSheetState();
}

class _NewCountSheetState extends State<_NewCountSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(
    text: '${DateFormat('MMMM yyyy').format(DateTime.now())} Full Count',
  );
  String? _category;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final error = await widget.vm.create(
      name: _name.text,
      locationId: widget.store!.id,
      category: _category,
    );
    // A failure shows inside the sheet (vm.createError).
    if (error == null && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.vm,
      builder: (context, _) => _buildForm(),
    );
  }

  Widget _buildForm() {
    final c = context.colors;
    final type = Theme.of(context).textTheme;
    final error = widget.vm.createError;
    final store = widget.store;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New count', style: type.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Every piece on sale is listed with the stock on record. Count what is really there, '
              'then finish the count to correct the stock.',
              style: type.bodySmall,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.edit_note_rounded, size: 20),
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Give the count a name.' : null,
            ),
            const SizedBox(height: 16),
            if (store == null)
              Text(
                'No store is set up yet, so there is nothing to count.',
                style: type.bodySmall!.copyWith(color: c.danger),
              )
            else
              Row(
                children: [
                  Icon(
                    Icons.storefront_outlined,
                    size: 18,
                    color: c.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Counts the stock at ${store.name}',
                      style: type.bodySmall,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            Text('WHAT TO COUNT', style: type.labelSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in StockCountsViewModel.categories.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: e.key == _category,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _category = e.key),
                  ),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error, style: type.bodySmall!.copyWith(color: c.danger)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: widget.vm.creating || store == null ? null : _save,
              child: _busyLabel(context, widget.vm.creating, 'Create count'),
            ),
          ],
        ),
      ),
    );
  }
}

/// One count: every line with what the books say and what was counted, the scanner, and
/// starting, finishing or cancelling the count.
class StockCountScreen extends StatefulWidget {
  final String countId;

  /// Tests pass their own; otherwise the screen makes and owns one.
  final StockCountViewModel? viewModel;

  const StockCountScreen({super.key, required this.countId, this.viewModel});

  @override
  State<StockCountScreen> createState() => _StockCountScreenState();
}

class _StockCountScreenState extends State<StockCountScreen> {
  late final StockCountViewModel _vm =
      widget.viewModel ?? StockCountViewModel(widget.countId);
  final _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    _vm.load();
  }

  @override
  void dispose() {
    if (widget.viewModel == null) _vm.dispose();
    _query.dispose();
    super.dispose();
  }

  /// A scan opens the matching line's count, ready for the number -- as the web puts the
  /// cursor in that row's box.
  Future<void> _scan() async {
    final code = await showScanSheet(
      context,
      title: 'Scan a piece',
      hint: 'Point at the barcode',
    );
    if (code == null || !mounted) return;
    final line = _vm.find(code);
    if (line == null) {
      showMessage(
        context,
        'No item in this audit matches "${code.trim()}".',
        error: true,
      );
      return;
    }
    _edit(line);
  }

  Future<void> _edit(StockCountItem line) => showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (_) => _CountSheet(vm: _vm, line: line),
  );

  Future<void> _addOne(StockCountItem line) async {
    final error = await _vm.addOne(line.id);
    if (error != null && mounted) showMessage(context, error, error: true);
  }

  Future<void> _start() async {
    final error = await _vm.start();
    if (!mounted) return;
    showMessage(
      context,
      error ?? 'Stock count started',
      error: error != null,
      success: error == null,
    );
  }

  Future<void> _complete() async {
    final counted = _vm.counted;
    final diff = _vm.differences;
    final todo = _vm.uncounted;
    final ok = await confirmAction(
      context,
      title: 'Finish this count?',
      message: [
        if (counted == 0)
          'Nothing has been counted, so no stock will change.'
        else if (diff == 0)
          'Every line you counted matches the stock on record, so no stock will change.'
        else
          '${_lines(diff)} you counted ${diff == 1 ? 'differs' : 'differ'} from the stock on record. '
              'The stock will be corrected to what you counted.',
        if (todo > 0 && counted > 0)
          '${_lines(todo)} not counted will be left as they are.',
        'This cannot be undone.',
      ].join(' '),
      confirmLabel: 'Finish count',
    );
    if (!ok || !mounted) return;
    final error = await _vm.complete();
    if (!mounted) return;
    if (error != null) {
      showMessage(context, error, error: true);
      return;
    }
    final adjusted = _vm.count!.adjustedItems ?? 0;
    showMessage(
      context,
      adjusted == 0
          ? 'Count finished. No stock needed correcting.'
          : 'Count finished. ${_lines(adjusted)} corrected in stock.',
      success: true,
    );
  }

  Future<void> _cancel() async {
    final ok = await confirmAction(
      context,
      title: 'Cancel this count?',
      message:
          'The count is closed and nobody can type into it again. No stock is changed, and what was '
          'already counted stays on it for reference. This cannot be undone.',
      confirmLabel: 'Cancel count',
      danger: true,
    );
    if (!ok || !mounted) return;
    final error = await _vm.cancel();
    if (!mounted) return;
    showMessage(
      context,
      error ?? 'Count cancelled. No stock was changed.',
      error: error != null,
      success: error == null,
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
    final session = SessionScope.of(context);
    final c = _vm.count;
    final error = _vm.error;
    final visible = _vm.visible;

    return Scaffold(
      bottomNavigationBar: c == null ? null : _bottomBar(session),
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(
              title: c?.name ?? 'Stock count',
              subtitle: _storeName(context, c?.locationId),
              actions: [
                if (_vm.canCancel(session.user))
                  TextButton(
                    onPressed: _vm.busy ? null : _cancel,
                    style: TextButton.styleFrom(
                      foregroundColor: context.colors.danger,
                    ),
                    child: const Text('Cancel count'),
                  ),
              ],
            ),
            Expanded(
              child: c == null && error != null
                  ? ErrorView.fromError(
                      error,
                      what: 'this audit',
                      onRetry: _vm.load,
                    )
                  : c == null
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          Skeleton(height: 140, radius: 12),
                          SizedBox(height: 16),
                          Skeleton(height: 70, radius: 12),
                          SizedBox(height: 10),
                          Skeleton(height: 70, radius: 12),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _vm.load,
                      // Every variant of the shop can be a line: built as they scroll into view.
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: visible.length + 1,
                        itemBuilder: (_, i) => i == 0
                            ? _top(c, visible.isEmpty)
                            : Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _line(
                                  visible[i - 1],
                                  session,
                                ).entrance((i - 1) % 12),
                              ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _bottomBar(AuthSession session) {
    final status = _vm.count!.status;
    final canStart = status == 'DRAFT' && session.can('stock_count:create');
    final canScan = _vm.counting && session.can('stock_count:update');
    final canFinish = _vm.counting && session.can('stock_count:complete');
    if (!canStart && !canScan && !canFinish) return null;
    final finish = FilledButton(
      // Not while a number is still on its way: finishing uses the server's.
      onPressed: _vm.busy || _vm.anySaving ? null : _complete,
      child: _busyLabel(context, _vm.busy, 'Finish count'),
    );
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: canStart
              ? FilledButton.icon(
                  onPressed: _vm.busy ? null : _start,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: _busyLabel(context, _vm.busy, 'Start counting'),
                )
              : Row(
                  children: [
                    if (canScan)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _scan,
                          icon: const Icon(Icons.qr_code_scanner_rounded),
                          label: const Text('Scan'),
                        ),
                      ),
                    if (canScan && canFinish) const SizedBox(width: 10),
                    if (canFinish) Expanded(child: finish),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _top(StockCount c, bool empty) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _summary(c).entrance(0),
        const SizedBox(height: 14),
        SearchField(
          controller: _query,
          hint: 'Name, SKU or barcode',
          onChanged: _vm.search,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final e in StockCountViewModel.filters.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('${e.value}  ${_vm.countOf(e.key)}'),
                    selected: _vm.filter == e.key,
                    showCheckmark: false,
                    onSelected: (_) => _vm.selectFilter(e.key),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (empty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Text(
              _vm.query.isNotEmpty
                  ? 'No line matches "${_query.text.trim()}".'
                  : _vm.filter == 'TODO'
                  ? 'Every line has been counted.'
                  : _vm.filter == 'DIFF'
                  ? 'No differences so far.'
                  : 'This count has no lines.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _summary(StockCount c) {
    final colours = context.colors;
    final type = Theme.of(context).textTheme;
    final note = type.bodySmall!.copyWith(height: 1.4);
    Widget big(String value, String rest, [Color? colour]) => Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          value,
          style: type.headlineSmall!.copyWith(
            color: colour,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(rest, style: type.bodySmall),
      ],
    );
    final total = _vm.total;
    final counted = _vm.counted;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _statusPill(c.status),
              const Spacer(),
              Text(
                'made ${_date.format(c.createdAt)}',
                style: type.labelMedium!.copyWith(color: colours.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (c.status == 'COMPLETED') ...[
            if (c.accuracy != null)
              big(
                '${c.accuracy!.toStringAsFixed(1)}%',
                ' of counted lines matched',
                _accuracyColour(context, c.accuracy!),
              )
            else
              Text('Nothing was counted.', style: note),
            const SizedBox(height: 8),
            Text(
              [
                '${_lines(c.adjustedItems ?? 0)} corrected in stock',
                '${c.matchedItems ?? 0} matched',
                if (_vm.uncounted > 0)
                  '${_vm.uncounted} not counted, left as they were',
              ].join(' • '),
              style: note,
            ),
          ] else if (c.status == 'CANCELLED')
            Text(
              'This count was cancelled'
              '${c.completedBy != null ? ' by ${c.completedBy}' : ''}'
              '${c.completedAt != null ? ' on ${_date.format(c.completedAt!)}' : ''}. '
              'No stock was changed. What was counted before then is kept below, for reference.',
              style: note,
            )
          else ...[
            big('$counted', ' / $total counted'),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : counted / total,
                minHeight: 8,
                backgroundColor: colours.input,
                color: colours.success,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              c.status == 'DRAFT'
                  ? 'Not started yet. Numbers can be entered once counting starts.'
                  : _vm.differences == 0
                  ? 'No differences so far.'
                  : '${_lines(_vm.differences)} with a difference so far.',
              style: note,
            ),
          ],
        ],
      ),
    );
  }

  Widget _line(StockCountItem l, AuthSession session) {
    final c = context.colors;
    final type = Theme.of(context).textTheme;
    final muted = type.labelMedium!.copyWith(color: c.textMuted);
    final diff = l.difference;
    final problem = _vm.lineError(l.id);
    final saving = _vm.isSaving(l.id);
    final canEdit = _vm.counting && session.can('stock_count:update');
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      onTap: canEdit ? () => _edit(l) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.title, style: type.titleSmall),
                    Text([l.sku, ?l.barcode].join(' • '), style: muted),
                    // The shop keeps selling during a count.
                    if (_vm.counting && l.onHand != l.expected)
                      Text(
                        'Now ${l.onHand} in stock',
                        style: type.labelMedium!.copyWith(color: c.warning),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    l.counted == null ? 'not counted' : '${l.counted}',
                    style: l.counted == null
                        ? muted
                        : type.titleMedium!.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                  ),
                  Text('expected ${l.expected}', style: muted),
                ],
              ),
              if (diff != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: tint(diff == 0 ? c.success : c.danger),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: diff == 0
                      ? Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: c.success,
                          semanticLabel: 'Matches',
                        )
                      : Text(
                          diff > 0 ? '+$diff' : '$diff',
                          style: type.labelMedium!.copyWith(color: c.danger),
                        ),
                ),
              ],
              if (canEdit) ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Add one piece',
                  child: Pressable(
                    onTap: saving ? null : () => _addOne(l),
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.input,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: c.border),
                      ),
                      child: saving
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: c.textSecondary,
                              ),
                            )
                          : Icon(
                              Icons.exposure_plus_1_rounded,
                              size: 20,
                              color: c.text,
                            ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (problem != null) ...[
            const SizedBox(height: 6),
            Text(problem, style: type.labelMedium!.copyWith(color: c.danger)),
          ],
        ],
      ),
    );
  }
}

/// Typing or stepping one line's counted pieces. The number being typed stays here until saved.
class _CountSheet extends StatefulWidget {
  final StockCountViewModel vm;
  final StockCountItem line;

  const _CountSheet({required this.vm, required this.line});

  @override
  State<_CountSheet> createState() => _CountSheetState();
}

class _CountSheetState extends State<_CountSheet> {
  late final _number = TextEditingController(
    text: widget.line.counted?.toString() ?? '',
  );

  int? get _value => int.tryParse(_number.text);

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  Future<void> _save(int? value) async {
    final error = await widget.vm.setCounted(widget.line.id, value);
    // A refusal shows inside the sheet (vm.lineError).
    if (error == null && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.vm,
      builder: (context, _) => _buildSheet(),
    );
  }

  Widget _buildSheet() {
    final c = context.colors;
    final type = Theme.of(context).textTheme;
    final l = widget.line;
    final saving = widget.vm.isSaving(l.id);
    final error = widget.vm.lineError(l.id);
    final value = _value;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.title, style: type.titleLarge),
          Text(
            [l.sku, ?l.barcode].join(' • '),
            style: type.labelMedium!.copyWith(color: c.textMuted),
          ),
          const SizedBox(height: 6),
          Text('Expected ${l.expected} on the books', style: type.bodySmall),
          const SizedBox(height: 16),
          Center(
            child: QuantityStepper(
              value: value ?? 0,
              onChanged: (v) => setState(() => _number.text = '$v'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _number,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: type.titleLarge!.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (_value != null && !saving) _save(_value);
            },
            decoration: const InputDecoration(hintText: 'Pieces counted'),
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(error, style: type.bodySmall!.copyWith(color: c.danger)),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              if (l.counted != null) ...[
                TextButton(
                  onPressed: saving ? null : () => _save(null),
                  child: const Text('Not counted'),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: FilledButton(
                  onPressed: saving || value == null
                      ? null
                      : () => _save(value),
                  child: _busyLabel(
                    context,
                    saving,
                    value == null ? 'Type the count' : 'Save: $value counted',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
