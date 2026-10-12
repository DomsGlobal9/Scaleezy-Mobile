import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../api/api_repository.dart';
import '../models/inventory_models.dart';
import '../theme/app_theme.dart';

/// Opens the movement dialog for [variant] and sends it to /inventory/stock-in or stock-out.
/// Resolves to true when the server accepted it, so the caller can refresh.
Future<bool> showStockMovement(
  BuildContext context, {
  required VariantItem variant,
  required String title,
  required bool isStockIn,
}) async {
  final repo = ApiRepository();
  final done = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => StockMovementDialog(
      title: title,
      sku: variant.sku,
      currentStock: '${variant.quantity}',
      isStockIn: isStockIn,
      onConfirm: (qty, reason, cost) => isStockIn
          ? repo.stockIn(
              variantId: variant.id,
              quantity: qty,
              reason: reason,
              unitCost: cost,
            )
          : repo.stockOut(variantId: variant.id, quantity: qty, reason: reason),
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
  final bool isStockIn;

  /// Runs the movement. Throwing [ApiException] keeps the dialog open with the server's message;
  /// returning closes it with `true`.
  final Future<void> Function(int qty, String reason, double? unitCost)
  onConfirm;

  const StockMovementDialog({
    super.key,
    required this.title,
    required this.sku,
    required this.currentStock,
    this.isStockIn = true,
    required this.onConfirm,
  });

  @override
  State<StockMovementDialog> createState() => _StockMovementDialogState();
}

class _StockMovementDialogState extends State<StockMovementDialog> {
  final TextEditingController _qtyController = TextEditingController(text: '1');
  final TextEditingController _costController = TextEditingController();
  late String _selectedReason;
  bool _busy = false;
  String? _error;

  final List<String> _stockInReasons = [
    // The same five the web app's Receive Stock offers, in its order.
    'PURCHASE',
    'RETURN',
    'INITIAL_STOCK',
    'SUPPLIER_DELIVERY',
    'PURCHASE_RECEIPT',
  ];

  // The only reasons the server takes for stock off by hand; sales remove stock themselves.
  final List<String> _stockOutReasons = [
    'DAMAGE',
    'SAMPLE',
    'RETURN_TO_VENDOR',
  ];

  @override
  void initState() {
    super.initState();
    _selectedReason = widget.isStockIn
        ? _stockInReasons.first
        : _stockOutReasons.first;
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _costController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final qty = int.tryParse(_qtyController.text.trim());
    if (qty == null || qty <= 0) {
      setState(
        () => _error = 'Enter how many pieces, as a whole number above zero.',
      );
      return;
    }
    final costText = _costController.text.trim();
    final cost = costText.isEmpty ? null : double.tryParse(costText);
    if (costText.isNotEmpty && cost == null) {
      setState(() => _error = 'That purchase cost is not a number.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onConfirm(qty, _selectedReason, cost);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    }
  }

  void _addQty(int amount) {
    final current = int.tryParse(_qtyController.text) ?? 0;
    final next = (current + amount).clamp(1, 9999);
    _qtyController.text = next.toString();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final reasons = widget.isStockIn ? _stockInReasons : _stockOutReasons;
    final primaryColor = widget.isStockIn
        ? AppColors.accentSuccess
        : AppColors.accentDanger;
    final primaryBg = widget.isStockIn
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
                        widget.isStockIn
                            ? Icons.add_box_rounded
                            : Icons.indeterminate_check_box_rounded,
                        color: primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      widget.isStockIn ? 'Receive Stock' : 'Issue Stock',
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
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
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
            if (widget.isStockIn) ...[
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
                  value: _selectedReason,
                  isExpanded: true,
                  dropdownColor: AppColors.bgCard,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  items: reasons.map((r) {
                    return DropdownMenuItem(
                      value: r,
                      child: Text(r.replaceAll('_', ' ')),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedReason = val);
                  },
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accentDangerLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _error!,
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
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
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
                    onPressed: _busy ? null : _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            widget.isStockIn ? 'Receive Stock' : 'Issue Stock',
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
