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

    _laserAnimation = Tween<double>(begin: 0.05, end: 0.95).animate(
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
        content: Text('Matched SKU: ${_scannedVariant.sku}'),
        backgroundColor: AppColors.textPrimary,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tag Scanner',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.6,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Code128 Barcodes & QR Codes',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.bgCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderLight),
                          boxShadow: AppColors.cardShadow,
                        ),
                        child: IconButton(
                          icon: Icon(
                            _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                            color: _isTorchOn ? AppColors.accentGold : AppColors.textSecondary,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _isTorchOn = !_isTorchOn),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Demo Shortcut Test Bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  const Text('Simulate: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                  _buildSimulateChip('Anarkali Red M', () => _simulateScan(0, 1)),
                  _buildSimulateChip('Banarasi Saree', () => _simulateScan(1, 1)),
                  _buildSimulateChip('Sherwani 40', () => _simulateScan(2, 1)),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Scanner Viewfinder Area
            Expanded(
              flex: 5,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Camera Grid / Crosshair Reticle
                      Container(
                        width: 260,
                        height: 160,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white24, width: 2),
                        ),
                      ),

                      // Gold Corner Brackets for Scanner Framing
                      SizedBox(
                        width: 270,
                        height: 170,
                        child: CustomPaint(
                          painter: ScannerReticlePainter(accentColor: AppColors.accentGold),
                        ),
                      ),

                      // Animated Laser Beam
                      AnimatedBuilder(
                        animation: _laserAnimation,
                        builder: (context, child) {
                          return Positioned(
                            top: (150 * _laserAnimation.value) + 70,
                            left: 50,
                            right: 50,
                            child: Container(
                              height: 2.5,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFDE68A),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.accentGold.withValues(alpha: 0.9),
                                    blurRadius: 12,
                                    spreadRadius: 3,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      // Hint Text Banner
                      Positioned(
                        bottom: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.crop_free_rounded, size: 14, color: Color(0xFFFDE68A)),
                              SizedBox(width: 8),
                              Text(
                                'Align 50x25mm garment tag inside box',
                                style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Live Scanned SKU Card
            Expanded(
              flex: 6,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  border: const Border(top: BorderSide(color: AppColors.borderLight)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accentSuccessLight,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.accentSuccess.withValues(alpha: 0.2)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle_rounded, size: 13, color: AppColors.accentSuccess),
                              SizedBox(width: 5),
                              Text(
                                'SKU Match Verified',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.accentSuccess,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'BARCODE: ${_scannedVariant.barcode}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
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
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_scannedVariant.sku} • ${_scannedVariant.colorName} • Size ${_scannedVariant.size}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 14),

                    // Metrics Strip
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
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMetricTile(
                            label: 'Reserved Qty',
                            value: '${_scannedVariant.reservedQty}',
                            unit: 'units',
                            color: AppColors.accentBlue,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMetricTile(
                            label: 'Unit WAC',
                            value: '₹${_scannedVariant.averageCost.toInt()}',
                            unit: 'cost',
                            color: AppColors.accentGold,
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Action Buttons Row
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.add_box_rounded, size: 18),
                            label: const Text('Stock In'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentSuccess,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                                        content: Text('Received $qty units to ${_scannedVariant.sku}!'),
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
                            icon: const Icon(Icons.indeterminate_check_box_rounded, size: 18),
                            label: const Text('Stock Out'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.accentDanger,
                              side: const BorderSide(color: AppColors.accentDanger),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                                        content: Text('Dispatched $qty units from ${_scannedVariant.sku}.'),
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
      ),
    );
  }

  Widget _buildSimulateChip(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ActionChip(
        label: Text(label),
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        backgroundColor: AppColors.bgCard,
        side: const BorderSide(color: AppColors.borderLight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onPressed: onTap,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: color, letterSpacing: -0.5),
              ),
              const SizedBox(width: 4),
              Text(unit, style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

class ScannerReticlePainter extends CustomPainter {
  final Color accentColor;

  ScannerReticlePainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accentColor
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLength = 24.0;

    // Top Left
    canvas.drawLine(const Offset(0, 0), const Offset(cornerLength, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, cornerLength), paint);

    // Top Right
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - cornerLength, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, cornerLength), paint);

    // Bottom Left
    canvas.drawLine(Offset(0, size.height), Offset(cornerLength, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - cornerLength), paint);

    // Bottom Right
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - cornerLength, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - cornerLength), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
