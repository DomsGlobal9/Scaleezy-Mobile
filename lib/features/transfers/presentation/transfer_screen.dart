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
      backgroundColor: AppColors.bgLight,
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
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
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
                        SizedBox(
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: _scan,
                            icon: const Icon(Icons.qr_code_scanner_rounded),
                            label: const Text(
                              'Scan',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.accentGold,
                              side: const BorderSide(
                                color: AppColors.accentGoldBorder,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).entrance(0),
                  const SizedBox(height: 12),
                  ..._searchResults(),
                  if (_vm.results == null && !_vm.searching) ..._lineCards(),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      controller: _notes,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Note (optional)',
                        hintText: 'e.g. For the Diwali display',
                        prefixIcon: const Icon(Icons.sticky_note_2_outlined),
                        filled: true,
                        fillColor: AppColors.bgCard,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: AppColors.textSecondary,
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: stores.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final l = stores[i];
        final sel = l.id == selected?.id;
        return Pressable(
          onTap: () => onTap(l),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sel ? AppColors.textPrimary : AppColors.bgCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: sel ? AppColors.textPrimary : AppColors.borderLight,
              ),
            ),
            child: Text(
              l.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: sel ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        );
      },
    ),
  );

  List<Widget> _searchResults() {
    final results = _vm.results;
    Widget pad(Widget child) =>
        Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: child);
    if (_vm.searching) {
      return [
        for (var i = 0; i < 3; i++) pad(const Skeleton(height: 64, radius: 18)),
      ];
    }
    if (_vm.searchError != null) {
      return [pad(_note(Icons.error_outline_rounded, _vm.searchError!))];
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
                const Icon(
                  Icons.add_circle_rounded,
                  color: AppColors.accentGold,
                ),
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
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _note(
            Icons.inventory_2_outlined,
            'Search or scan the items to move. Only what ${_vm.from?.name ?? 'the store'} has can be moved.',
          ),
        ),
      ];
    }
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SectionHeader(title: 'To move', trailing: _pieces(_vm.pieces)),
      ),
      for (final (i, l) in _vm.lines.indexed)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.borderLight),
            ),
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
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ).entrance(i % 12),
        ),
    ];
  }

  Widget _itemText(StoreStock s) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(s.title, style: const TextStyle(fontWeight: FontWeight.w800)),
      Text(
        s.sku,
        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
      ),
      Text(
        '${s.quantity} at ${_vm.from?.name}',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.accentBlue,
        ),
      ),
    ],
  );

  Widget _note(IconData icon, String text) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.bgSurface,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _moveBar() {
    final error = _vm.error;
    final pieces = _vm.pieces;
    return SafeArea(
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
                onPressed: _vm.busy ? null : _move,
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
                        pieces == 0
                            ? 'Add items to move'
                            : 'Move ${_pieces(pieces)}',
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
    );
  }

  Widget _result(MovedStock moved) {
    final canPutAway = SessionScope.of(context).can('shelf:putaway');
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const PageHeader(title: 'Move to another store'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SurfaceCard(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(
                    color: AppColors.accentSuccessLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 32,
                    color: AppColors.accentSuccess,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Moved ${_pieces(moved.pieces)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${moved.items} ${moved.items == 1 ? 'item' : 'items'} • ${moved.from.name} → ${moved.to.name}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'At ${moved.to.name} they are not on a shelf yet. Put them away from Shelves.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ).entrance(0),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
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
                  label: Text(
                    'Put away at ${moved.to.name}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentGold,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              OutlinedButton(
                onPressed: _vm.startOver,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.borderLight),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Move more',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
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
