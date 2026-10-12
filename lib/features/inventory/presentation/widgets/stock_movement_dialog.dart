import 'package:flutter/material.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/core/widgets/async_state.dart';
import 'package:scaleezy/features/inventory/presentation/view_models/stock_movement_view_model.dart';
import 'package:scaleezy/features/products/data/product_models.dart';

/// Opens the movement dialog for [variant] and sends it to /inventory/stock-in or stock-out.
/// Resolves to true when the server accepted it, so the caller can refresh.
Future<bool> showStockMovement(
  BuildContext context, {
  required VariantItem variant,
  required String title,
  required bool isStockIn,
}) async {
  final done = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => StockMovementDialog(
      title: title,
      sku: variant.sku,
      currentStock: '${variant.quantity}',
      variantId: variant.id,
      isStockIn: isStockIn,
    ),
  );
  if (done == true && context.mounted) {
    showMessage(
      context,
      isStockIn ? 'Stock added successfully' : 'Stock deducted successfully',
      success: true,
    );
  }
  return done == true;
}

class StockMovementDialog extends StatefulWidget {
  final String title;
  final String sku;
  final String currentStock;
  final String variantId;
  final bool isStockIn;

  /// Tests pass their own; otherwise the dialog makes and owns one. A server error keeps the
  /// dialog open with its message; success closes it with `true`.
  final StockMovementViewModel? viewModel;

  const StockMovementDialog({
    super.key,
    required this.title,
    required this.sku,
    required this.currentStock,
    required this.variantId,
    this.isStockIn = true,
    this.viewModel,
  });

  @override
  State<StockMovementDialog> createState() => _StockMovementDialogState();
}

class _StockMovementDialogState extends State<StockMovementDialog> {
  late final StockMovementViewModel _vm =
      widget.viewModel ??
      StockMovementViewModel(
        variantId: widget.variantId,
        isStockIn: widget.isStockIn,
      );
  late final TextEditingController _qtyController = TextEditingController(
    text: _vm.quantity,
  );
  late final TextEditingController _costController = TextEditingController(
    text: _vm.cost,
  );

  @override
  void dispose() {
    _qtyController.dispose();
    _costController.dispose();
    if (widget.viewModel == null) _vm.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final error = await _vm.save();
    if (error == null && mounted) Navigator.of(context).pop(true);
  }

  void _addQty(int amount) => _qtyController.text = _vm.addQuantity(amount);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => _buildDialog(),
    );
  }

  Widget _buildDialog() {
    final c = context.colors;
    final type = Theme.of(context).textTheme;
    final tone = _vm.isStockIn ? c.success : c.danger;
    final action = _vm.isStockIn ? 'Receive Stock' : 'Issue Stock';

    return Dialog(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tint(tone),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _vm.isStockIn ? Icons.add_rounded : Icons.remove_rounded,
                    color: tone,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(action, style: type.titleLarge)),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: c.textSecondary,
                  onPressed: _vm.busy
                      ? null
                      : () => Navigator.of(context).pop(),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.input,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: type.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.sku,
                          style: type.labelMedium!.copyWith(
                            color: c.textMuted,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('IN STOCK', style: type.labelSmall),
                      Text(
                        '${widget.currentStock} pieces',
                        style: type.titleSmall!.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _qtyController,
              onChanged: (text) => _vm.quantity = text,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                hintText: 'Enter quantity',
                prefixIcon: Icon(Icons.numbers_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final n in const [1, 5, 10, 25]) ...[
                  _qtyPill('+$n', n),
                  const SizedBox(width: 6),
                ],
              ],
            ),
            if (_vm.isStockIn) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _costController,
                onChanged: (text) => _vm.cost = text,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'What you paid per piece (₹)',
                  hintText: 'Optional unit purchase price',
                  prefixIcon: Icon(Icons.currency_rupee_rounded, size: 18),
                ),
              ),
            ],
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _vm.reason,
              isExpanded: true,
              hint: const Text('Choose a reason…'),
              decoration: const InputDecoration(labelText: 'Reason'),
              items: [
                for (final r in _vm.reasons)
                  DropdownMenuItem(
                    value: r,
                    child: Text(StockMovementViewModel.reasonLabels[r] ?? r),
                  ),
              ],
              onChanged: _vm.busy ? null : (val) => _vm.reason = val,
            ),
            if (_vm.error != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tint(c.danger),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _vm.error!,
                  style: type.bodySmall!.copyWith(color: c.danger),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _vm.busy
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _vm.busy ? null : _confirm,
                    child: _vm.busy
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: c.card,
                            ),
                          )
                        : Text(action),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _qtyPill(String label, int amount) {
    final c = context.colors;
    return InkWell(
      onTap: () => _addQty(amount),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: c.input,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.border),
        ),
        child: Text(label, style: Theme.of(context).textTheme.labelMedium),
      ),
    );
  }
}
