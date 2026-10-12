import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:scaleezy/app/app_routes.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/shop/shop_context.dart';
import 'package:scaleezy/core/shop/shop_models.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/core/widgets/async_state.dart';
import 'package:scaleezy/core/widgets/scan_sheet.dart';
import 'package:scaleezy/core/widgets/ui.dart';
import 'package:scaleezy/features/stock_counts/data/stock_count_models.dart';
import 'package:scaleezy/features/stock_counts/presentation/view_models/stock_count_view_model.dart';
import 'package:scaleezy/features/stock_counts/presentation/view_models/stock_counts_view_model.dart';

final _date = DateFormat('d MMM');

String _lines(int n) => '$n ${n == 1 ? 'line' : 'lines'}';

/// The list answers only the store's id; its name comes from the shop's stores.
String? _storeName(BuildContext context, String? id) =>
    ShopScope.of(context).locations.where((l) => l.id == id).firstOrNull?.name;

Widget _statusChip(String status) {
  final (fg, bg) = switch (status) {
    'IN_PROGRESS' => (AppColors.accentWarning, AppColors.accentGoldLight),
    'COMPLETED' => (AppColors.accentSuccess, AppColors.accentSuccessLight),
    'CANCELLED' => (AppColors.accentDanger, AppColors.accentDangerLight),
    _ => (AppColors.textSecondary, AppColors.bgSurface),
  };
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

Widget _choice(String label, bool selected, VoidCallback onTap) => Padding(
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
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    onSelected: (_) => onTap(),
  ),
);

Widget _busyLabel(bool busy, String label) => busy
    ? const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
      )
    : Text(label, style: const TextStyle(fontWeight: FontWeight.w800));

ButtonStyle _bigButton(Color colour) => FilledButton.styleFrom(
  backgroundColor: colour,
  padding: const EdgeInsets.symmetric(vertical: 16),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
);

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
    final shop = ShopScope.read(context);
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => _NewCountSheet(
        vm: _vm,
        stores: shop.locations,
        initial: StockCountsViewModel.defaultStore(
          shop.selectedLocation,
          shop.locations,
        ),
      ),
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
      backgroundColor: AppColors.bgLight,
      floatingActionButton: SessionScope.of(context).can('stock_count:create')
          ? FloatingActionButton.extended(
              onPressed: _new,
              backgroundColor: AppColors.accentGold,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'New count',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
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
                  ? ErrorView(message: error, onRetry: _vm.load)
                  : list == null
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
                  ? const ErrorView(
                      message:
                          'No stock counts yet. Start one to check what is on the shelves against the stock on record.',
                    )
                  : RefreshIndicator(
                      color: AppColors.accentGold,
                      onRefresh: _vm.load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
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
    final counted = c.countedItems;
    final accuracy = c.accuracy;
    return SurfaceCard(
      onTap: () => _open(c.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  c.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _statusChip(c.status),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            [
              ?_storeName(context, c.locationId),
              'made ${_date.format(c.createdAt)}',
            ].join(' • '),
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  counted != null
                      ? '$counted of ${c.itemCount} counted'
                      : '${c.itemCount} ${c.itemCount == 1 ? 'item' : 'items'}${c.isOpen ? ' to count' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              if (accuracy != null)
                Text(
                  '${accuracy.toStringAsFixed(1)}% matched',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: accuracy >= 95
                        ? AppColors.accentSuccess
                        : AppColors.accentDanger,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Name, store and (optionally) one category. The draft stays here; the list's view model
/// makes the count.
class _NewCountSheet extends StatefulWidget {
  final StockCountsViewModel vm;
  final List<StockLocation> stores;
  final StockLocation? initial;

  const _NewCountSheet({required this.vm, required this.stores, this.initial});

  @override
  State<_NewCountSheet> createState() => _NewCountSheetState();
}

class _NewCountSheetState extends State<_NewCountSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(
    text: '${DateFormat('MMMM yyyy').format(DateTime.now())} Full Count',
  );
  late StockLocation? _store = widget.initial;
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
      locationId: _store!.id,
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
    final error = widget.vm.createError;
    const label = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w800,
      color: AppColors.textSecondary,
    );
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'New count',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            const Text(
              'Every piece on sale is listed with the stock on record. Count what is really there, '
              'then finish the count to correct the stock.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Name',
                prefixIcon: const Icon(Icons.edit_note_rounded, size: 20),
                filled: true,
                fillColor: AppColors.bgSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Give the count a name.' : null,
            ),
            const SizedBox(height: 16),
            if (widget.stores.isEmpty)
              const Text(
                'No store is set up yet, so there is nothing to count.',
                style: TextStyle(
                  color: AppColors.accentDanger,
                  fontWeight: FontWeight.w600,
                ),
              )
            else if (widget.stores.length > 1) ...[
              const Text('Store', style: label),
              const SizedBox(height: 8),
              Wrap(
                children: [
                  for (final s in widget.stores)
                    _choice(
                      s.name,
                      s.id == _store?.id,
                      () => setState(() => _store = s),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            const Text('What to count', style: label),
            const SizedBox(height: 8),
            Wrap(
              children: [
                for (final e in StockCountsViewModel.categories.entries)
                  _choice(
                    e.value,
                    e.key == _category,
                    () => setState(() => _category = e.key),
                  ),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error,
                style: const TextStyle(
                  color: AppColors.accentDanger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: widget.vm.creating || _store == null ? null : _save,
              style: _bigButton(AppColors.accentGold),
              child: _busyLabel(widget.vm.creating, 'Create count'),
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
      hint: 'Point the camera at the tag',
    );
    if (code == null || !mounted) return;
    final line = _vm.find(code);
    if (line == null) {
      showMessage(
        context,
        'No item in this count matches "${code.trim()}".',
        error: true,
      );
      return;
    }
    _edit(line);
  }

  Future<void> _edit(StockCountItem line) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bgCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (_) => _CountSheet(vm: _vm, line: line),
  );

  Future<void> _addOne(StockCountItem line) async {
    final error = await _vm.addOne(line.id);
    if (error != null && mounted) showMessage(context, error, error: true);
  }

  Future<void> _start() async {
    final error = await _vm.start();
    if (!mounted) return;
    if (error != null) showMessage(context, error, error: true);
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
      backgroundColor: AppColors.bgLight,
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
                      foregroundColor: AppColors.accentDanger,
                    ),
                    child: const Text(
                      'Cancel count',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: c == null && error != null
                  ? ErrorView(message: error, onRetry: _vm.load)
                  : c == null
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          Skeleton(height: 140, radius: 22),
                          SizedBox(height: 16),
                          Skeleton(height: 70, radius: 18),
                          SizedBox(height: 8),
                          Skeleton(height: 70, radius: 18),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: AppColors.accentGold,
                      onRefresh: _vm.load,
                      // Every variant of the shop can be a line: built as they scroll into view.
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: visible.length + 1,
                        itemBuilder: (_, i) => i == 0
                            ? _top(c, visible.isEmpty)
                            : Padding(
                                padding: const EdgeInsets.only(bottom: 8),
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
      style: _bigButton(AppColors.accentSuccess).copyWith(
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        ),
      ),
      child: _busyLabel(_vm.busy, 'Finish count'),
    );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: canStart
            ? FilledButton.icon(
                onPressed: _vm.busy ? null : _start,
                icon: const Icon(Icons.play_arrow_rounded),
                label: _busyLabel(_vm.busy, 'Start counting'),
                style: _bigButton(AppColors.accentGold),
              )
            : Row(
                children: [
                  if (canScan)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _scan,
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: const Text(
                          'Scan',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        style: _bigButton(AppColors.accentGold),
                      ),
                    ),
                  if (canScan && canFinish) const SizedBox(width: 10),
                  if (canFinish) canScan ? finish : Expanded(child: finish),
                ],
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
                        '${e.value}  ${_vm.countOf(e.key)}',
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
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _summary(StockCount c) {
    const note = TextStyle(
      fontSize: 12,
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w600,
      height: 1.4,
    );
    Widget big(String value, String rest) => Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        Text(
          rest,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
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
              _statusChip(c.status),
              const Spacer(),
              Text(
                'made ${_date.format(c.createdAt)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (c.status == 'COMPLETED') ...[
            if (c.accuracy != null)
              big(
                '${c.accuracy!.toStringAsFixed(1)}%',
                ' of counted lines matched',
              )
            else
              const Text('Nothing was counted.', style: note),
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
                minHeight: 10,
                backgroundColor: AppColors.bgSurface,
                color: AppColors.accentSuccess,
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
                    Text(
                      l.title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      [l.sku, ?l.barcode].join(' • '),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                    // The shop keeps selling during a count.
                    if (_vm.counting && l.onHand != l.expected)
                      Text(
                        'Now ${l.onHand} in stock',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentWarning,
                        ),
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
                        ? const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                          )
                        : const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                  ),
                  Text(
                    'expected ${l.expected}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              if (diff != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: diff == 0
                        ? AppColors.accentSuccessLight
                        : AppColors.accentDangerLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: diff == 0
                      ? const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: AppColors.accentSuccess,
                          semanticLabel: 'Matches',
                        )
                      : Text(
                          diff > 0 ? '+$diff' : '$diff',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accentDanger,
                          ),
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
                        color: AppColors.accentGoldLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.accentGoldBorder),
                      ),
                      child: saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.accentGold,
                              ),
                            )
                          : const Icon(
                              Icons.exposure_plus_1_rounded,
                              size: 20,
                              color: AppColors.accentGold,
                            ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (problem != null) ...[
            const SizedBox(height: 6),
            Text(
              problem,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.accentDanger,
              ),
            ),
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
    final l = widget.line;
    final saving = widget.vm.isSaving(l.id);
    final error = widget.vm.lineError(l.id);
    final value = _value;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          Text(
            [l.sku, ?l.barcode].join(' • '),
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 6),
          Text(
            'Expected ${l.expected} on the books',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
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
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (_value != null && !saving) _save(_value);
            },
            decoration: InputDecoration(
              hintText: 'Pieces counted',
              hintStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
              filled: true,
              fillColor: AppColors.bgSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(
              error,
              style: const TextStyle(
                color: AppColors.accentDanger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              if (l.counted != null) ...[
                TextButton(
                  onPressed: saving ? null : () => _save(null),
                  child: const Text(
                    'Not counted',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: FilledButton(
                  onPressed: saving || value == null
                      ? null
                      : () => _save(value),
                  style: _bigButton(AppColors.accentGold),
                  child: _busyLabel(
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
