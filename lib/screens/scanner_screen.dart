import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/mock_data.dart';
import '../models/inventory_models.dart';
import '../widgets/stock_movement_dialog.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _laserAnimation;
  bool _isTorchOn = false;

  // Selected or active scanned variant
  VariantItem _scannedVariant = MockData.products[0].variants[1]; // Red Anarkali Size M
  ProductItem _scannedProduct = MockData.products[0];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.1, end: 0.9).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _simulateScan(int productIndex, int variantIndex) {
    setState(() {
      _scannedProduct = MockData.products[productIndex];
      _scannedVariant = _scannedProduct.variants[variantIndex];
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Scanned: ${_scannedVariant.sku}'),
        backgroundColor: AppColors.accentGold,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: const Text('Mobile Barcode Scanner'),
        actions: [
          IconButton(
            icon: Icon(
              _isTorchOn ? Icons.flash_on : Icons.flash_off,
              color: _isTorchOn ? AppColors.accentGold : AppColors.textSecondary,
            ),
            onPressed: () => setState(() => _isTorchOn = !_isTorchOn),
          ),
        ],
      ),
      body: Column(
        children: [
          // Viewfinder Container
          Expanded(
            flex: 5,
            child: Container(
              margin: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderFocus),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Background camera viewfinder simulation grid
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.center,
                            radius: 0.8,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.6),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Targeting Crosshair / Reticle Box
                    Container(
                      width: 250,
                      height: 160,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.8), width: 2),
                      ),
                    ),

                    // Animated Scanning Laser Beam
                    AnimatedBuilder(
                      animation: _laserAnimation,
                      builder: (context, child) {
                        return Positioned(
                          top: (160 * _laserAnimation.value) + 80,
                          left: 45,
                          right: 45,
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              color: AppColors.accentGold,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accentGold.withValues(alpha: 0.8),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    // Instruction Banner
                    Positioned(
                      bottom: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.qr_code, size: 14, color: AppColors.accentGold),
                            SizedBox(width: 8),
                            Text(
                              'Align 50x25mm garment tag in box',
                              style: TextStyle(fontSize: 11, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Simulation Shortcut Buttons (Quick testing)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_horiz, color: Colors.white70),
                        color: AppColors.bgSurface,
                        tooltip: 'Simulate barcode scan',
                        onSelected: (val) {
                          if (val == 'anarkali') _simulateScan(0, 1);
                          if (val == 'saree') _simulateScan(1, 1);
                          if (val == 'sherwani') _simulateScan(2, 1);
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(value: 'anarkali', child: Text('Scan Anarkali Size M')),
                          const PopupMenuItem(value: 'saree', child: Text('Scan Banarasi Saree')),
                          const PopupMenuItem(value: 'sherwani', child: Text('Scan Velvet Sherwani')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Scanned Product Details & Instant Actions
          Expanded(
            flex: 6,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              decoration: const BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: AppColors.borderLight)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.accentSuccess.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.check_circle, size: 14, color: AppColors.accentSuccess),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Active SKU Match Found',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accentSuccess,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Barcode: ${_scannedVariant.barcode}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _scannedProduct.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_scannedVariant.sku} • ${_scannedVariant.colorName} • Size ${_scannedVariant.size}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 14),

                  // Stock & Cost breakdown cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricTile(
                          label: 'Physical Stock',
                          value: '${_scannedVariant.quantity}',
                          unit: 'units',
                          color: _scannedVariant.quantity <= 3 ? AppColors.accentDanger : AppColors.accentSuccess,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMetricTile(
                          label: 'Reserved Qty',
                          value: '${_scannedVariant.reservedQty}',
                          unit: 'units',
                          color: AppColors.accentBlue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMetricTile(
                          label: 'Weighted Cost',
                          value: '₹${_scannedVariant.averageCost.toInt()}',
                          unit: 'WAC',
                          color: AppColors.accentGold,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Quick Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add_box_outlined, size: 18),
                          label: const Text('Stock In'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentSuccess,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => StockMovementDialog(
                                title: '${_scannedProduct.title} (${_scannedVariant.size})',
                                sku: _scannedVariant.sku,
                                currentStock: '${_scannedVariant.quantity}',
                                isStockIn: true,
                                onConfirm: (qty, reason, cost) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Received $qty units to inventory!'),
                                      backgroundColor: AppColors.accentSuccess,
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.indeterminate_check_box_outlined, size: 18),
                          label: const Text('Stock Out'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.accentDanger,
                            side: const BorderSide(color: AppColors.accentDanger),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => StockMovementDialog(
                                title: '${_scannedProduct.title} (${_scannedVariant.size})',
                                sku: _scannedVariant.sku,
                                currentStock: '${_scannedVariant.quantity}',
                                isStockIn: false,
                                onConfirm: (qty, reason, cost) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Dispatched $qty units from stock.'),
                                      backgroundColor: AppColors.accentDanger,
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color),
              ),
              const SizedBox(width: 4),
              Text(unit, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}
