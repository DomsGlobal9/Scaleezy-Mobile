import 'package:flutter/material.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isStockIn
              ? 'Received into ${variant.sku}.'
              : 'Taken out of ${variant.sku}.',
        ),
        backgroundColor: isStockIn
            ? AppColors.accentSuccess
            : AppColors.accentDanger,
      ),
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
    final primaryColor = _vm.isStockIn
        ? AppColors.accentSuccess
        : AppColors.accentDanger;
    final primaryBg = _vm.isStockIn
        ? AppColors.accentSuccessLight
        : AppColors.accentDangerLight;

    return Dialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _vm.isStockIn
                            ? Icons.add_box_rounded
                            : Icons.indeterminate_check_box_rounded,
                        color: primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _vm.isStockIn ? 'Receive Stock' : 'Issue Stock',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
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
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.sku,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
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
                      const Text(
                        'Current Stock',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${widget.currentStock} units',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Quantity',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _qtyController,
              onChanged: (text) => _vm.quantity = text,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.bgInput,
                hintText: 'Enter quantity',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                prefixIcon: const Icon(
                  Icons.numbers_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.accentGold),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Quick Quantity Stepper Pills
            Row(
              children: [
                _buildQtyPill('+1', 1),
                const SizedBox(width: 6),
                _buildQtyPill('+5', 5),
                const SizedBox(width: 6),
                _buildQtyPill('+10', 10),
                const SizedBox(width: 6),
                _buildQtyPill('+25', 25),
              ],
            ),
            if (_vm.isStockIn) ...[
              const SizedBox(height: 14),
              const Text(
                'Unit Purchase Cost (₹) for WAC valuation',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _costController,
                onChanged: (text) => _vm.cost = text,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.bgInput,
                  hintText: 'Optional unit purchase price',
                  hintStyle: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.currency_rupee_rounded,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.borderLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.accentGold),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            const Text(
              'Reason',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.bgInput,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _vm.reason,
                  isExpanded: true,
                  dropdownColor: AppColors.bgCard,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  items: _vm.reasons.map((r) {
                    return DropdownMenuItem(
                      value: r,
                      child: Text(r.replaceAll('_', ' ')),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) _vm.reason = val;
                  },
                ),
              ),
            ),
            if (_vm.error != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accentDangerLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _vm.error!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentDanger,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _vm.busy
                        ? null
                        : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.borderLight),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _vm.busy ? null : _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _vm.busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _vm.isStockIn ? 'Receive Stock' : 'Issue Stock',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQtyPill(String label, int amount) {
    return GestureDetector(
      onTap: () => _addQty(amount),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
