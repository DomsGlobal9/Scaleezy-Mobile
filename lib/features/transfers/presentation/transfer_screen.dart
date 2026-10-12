import 'package:flutter/material.dart';

import 'package:scaleezy/app/app_routes.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/shop/shop_context.dart';
import 'package:scaleezy/core/shop/shop_models.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/core/widgets/async_state.dart';
import 'package:scaleezy/core/widgets/scan_sheet.dart';
import 'package:scaleezy/core/widgets/ui.dart';
import 'package:scaleezy/features/transfers/data/transfer_models.dart';
import 'package:scaleezy/features/transfers/presentation/view_models/transfer_view_model.dart';

String _pieces(int n) => '$n ${n == 1 ? 'piece' : 'pieces'}';

/// Move pieces from one store to another, for example from the shop to the godown.
class TransferScreen extends StatefulWidget {
  /// Tests pass their own; otherwise the screen makes and owns one.
  final TransferViewModel? viewModel;

  const TransferScreen({super.key, this.viewModel});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  late final TransferViewModel _vm = widget.viewModel ?? TransferViewModel();
  final _search = TextEditingController();
  final _notes = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Until a store is known, try again whenever the shop's stores change.
    if (_vm.from == null) {
      final shop = ShopScope.of(context);
      _vm.start(shop.selectedLocation, shop.locations);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _notes.dispose();
    if (widget.viewModel == null) _vm.dispose();
    super.dispose();
  }

  Future<void> _pickFrom(StockLocation store) async {
    final from = _vm.from;
    if (store.id == from?.id) return;
    if (_vm.lines.isNotEmpty &&
        !await confirmAction(
          context,
          title: 'Move from ${store.name}?',
          message:
              'The list was made for ${from?.name}. Changing the store empties it.',
          confirmLabel: 'Change store',
        )) {
      return;
    }
    _search.clear();
    _vm.pickFrom(store);
  }

  void _add(StoreStock item) {
    final before = _vm.pieces;
    final message = _vm.add(item);
    // Nothing added: every piece the store has is listed already.
    if (_vm.pieces == before) showMessage(context, message);
    _search.clear();
    _vm.clearSearch();
  }

  Future<void> _scan() async {
    await showScanSheet(
      context,
      title: 'Scan each piece',
      hint: 'One scan = one piece',
      onCode: _vm.scan,
    );
  }

  Future<void> _move() async {
    if (_vm.validate() != null) return;
    final from = _vm.from!.name, to = _vm.to!.name;
    final items = _vm.lines.length;
    final ok = await confirmAction(
      context,
      title: 'Move ${_pieces(_vm.pieces)} from $from to $to?',
      message:
          '$items ${items == 1 ? 'item' : 'items'}. The stock moves straight away. Pieces not on a '
          'shelf at $from go first; at $to they wait to be put away.',
      confirmLabel: 'Move now',
    );
    if (!ok || !mounted) return;
    if (await _vm.move(_notes.text)) {
      _notes.clear();
    } else if (mounted && _vm.error != null) {
      showMessage(context, _vm.error!, error: true);
    }
  }

  Future<void> _leave() async {
    final ok = await confirmAction(
      context,
      title: 'Leave without moving?',
      message:
          'The pieces you listed have not moved yet. Leaving forgets the list.',
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
        canPop: _vm.lines.isEmpty,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _leave();
        },
        child: _buildScreen(),
      ),
    );
  }

  Widget _buildScreen() {
    final moved = _vm.moved;
    return Scaffold(
      bottomNavigationBar: moved == null ? _moveBar() : null,
      body: SafeArea(
        child: moved != null
            ? _result(moved)
            : ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  const PageHeader(
                    title: 'Move to another store',
                    subtitle: 'The stock moves straight away',
                  ),
                  _label('From'),
                  _storeChips(_vm.stores, _vm.from, _pickFrom),
                  _label('To'),
                  _storeChips(_vm.destinations, _vm.to, _vm.pickTo),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: SearchField(
                            controller: _search,
                            hint: 'Search name, SKU or barcode',
                            onChanged: (v) {
                              setState(
                                () {},
                              ); // shows or hides the clear button
                              _vm.typed(v);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: _scan,
                          icon: const Icon(Icons.qr_code_scanner_rounded),
                          label: const Text('Scan'),
                        ),
                      ],
                    ),
                  ).entrance(0),
                  const SizedBox(height: 12),
                  ..._searchResults(),
                  if (_vm.results == null && !_vm.searching) ..._lineCards(),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _notes,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                        hintText: 'e.g. For the Diwali display',
                        prefixIcon: Icon(Icons.sticky_note_2_outlined),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall,
    ),
  );

  Widget _storeChips(
    List<StockLocation> stores,
    StockLocation? selected,
    void Function(StockLocation) onTap,
  ) => SizedBox(
    height: 44,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: stores.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final l = stores[i];
        return ChoiceChip(
          label: Text(l.name),
          selected: l.id == selected?.id,
          showCheckmark: false,
          onSelected: (_) => onTap(l),
        );
      },
    ),
  );

  List<Widget> _searchResults() {
    final results = _vm.results;
    Widget pad(Widget child) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: child,
    );
    if (_vm.searching) {
      return [
        for (var i = 0; i < 3; i++) pad(const Skeleton(height: 64, radius: 12)),
      ];
    }
    if (_vm.searchError != null) {
      return [
        pad(
          _note(
            Icons.warning_amber_rounded,
            _vm.searchError!,
            context.colors.danger,
          ),
        ),
      ];
    }
    if (results == null) return const [];
    if (results.isEmpty) {
      return [
        pad(
          _note(
            Icons.search_off_rounded,
            'Nothing at ${_vm.from?.name} matches that.',
          ),
        ),
      ];
    }
    return [
      for (final (i, r) in results.indexed)
        pad(
          SurfaceCard(
            padding: const EdgeInsets.all(14),
            onTap: () => _add(r),
            child: Row(
              children: [
                Expanded(child: _itemText(r)),
                Icon(Icons.add_circle_rounded, color: context.colors.brandInk),
              ],
            ),
          ).entrance(i % 12),
        ),
    ];
  }

  List<Widget> _lineCards() {
    if (_vm.lines.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _note(
            Icons.inventory_2_outlined,
            'Search or scan the items to move. Only what ${_vm.from?.name ?? 'the store'} has can be moved.',
          ),
        ),
      ];
    }
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SectionHeader(title: 'To move', trailing: _pieces(_vm.pieces)),
      ),
      for (final (i, l) in _vm.lines.indexed)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: SurfaceCard(
            padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
            child: Row(
              children: [
                Expanded(child: _itemText(l)),
                QuantityStepper(
                  value: _vm.qty(l.variantId),
                  min: 1,
                  max: l.quantity,
                  onChanged: (v) => _vm.setQty(l.variantId, v),
                ),
                IconButton(
                  tooltip: 'Take off the list',
                  onPressed: () => _vm.remove(l.variantId),
                  color: context.colors.textMuted,
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
          ).entrance(i % 12),
        ),
    ];
  }

  Widget _itemText(StoreStock s) {
    final type = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.title, style: type.titleSmall),
        Text(s.sku, style: type.bodySmall),
        Text(
          '${s.quantity} at ${_vm.from?.name}',
          style: type.labelMedium!.copyWith(color: context.colors.textMuted),
        ),
      ],
    );
  }

  Widget _note(IconData icon, String text, [Color? colour]) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.input,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colour ?? c.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall!.copyWith(color: colour),
            ),
          ),
        ],
      ),
    );
  }

  Widget _moveBar() {
    final c = context.colors;
    final error = _vm.error;
    final pieces = _vm.pieces;
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    error,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall!.copyWith(color: c.danger),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _vm.busy ? null : _move,
                  child: _vm.busy
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: c.card,
                          ),
                        )
                      : Text(
                          pieces == 0
                              ? 'Add items to move'
                              : 'Move ${_pieces(pieces)}',
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _result(MovedStock moved) {
    final c = context.colors;
    final type = Theme.of(context).textTheme;
    final canPutAway = SessionScope.of(context).can('shelf:putaway');
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const PageHeader(title: 'Move to another store'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SurfaceCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: tint(c.success),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check_rounded, size: 32, color: c.success),
                ),
                const SizedBox(height: 14),
                Text('Moved ${_pieces(moved.pieces)}', style: type.titleLarge),
                const SizedBox(height: 4),
                Text(
                  '${moved.items} ${moved.items == 1 ? 'item' : 'items'} • ${moved.from.name} → ${moved.to.name}',
                  textAlign: TextAlign.center,
                  style: type.bodySmall,
                ),
                const SizedBox(height: 12),
                Text(
                  'At ${moved.to.name} they are not on a shelf yet. Put them away from Shelves.',
                  textAlign: TextAlign.center,
                  style: type.labelMedium!.copyWith(color: c.textMuted),
                ),
              ],
            ),
          ).entrance(0),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (canPutAway) ...[
                FilledButton.icon(
                  onPressed: () => AppRoutes.waitingToShelve(
                    context,
                    locationId: moved.to.id,
                  ),
                  icon: const Icon(Icons.shelves),
                  label: Text('Put away at ${moved.to.name}'),
                ),
                const SizedBox(height: 10),
              ],
              OutlinedButton(
                onPressed: _vm.startOver,
                child: const Text('Move more'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Done'),
              ),
            ],
          ).entrance(1),
        ),
      ],
    );
  }
}
