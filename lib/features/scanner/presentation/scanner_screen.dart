import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:scaleezy/app/app_routes.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/core/utils/money.dart';
import 'package:scaleezy/core/widgets/ui.dart';
import 'package:scaleezy/features/inventory/presentation/widgets/stock_movement_dialog.dart';
import 'package:scaleezy/features/products/data/product_models.dart';
import 'package:scaleezy/features/scanner/presentation/view_models/scanner_view_model.dart';

class ScannerScreen extends StatefulWidget {
  /// False while another tab is showing, so the camera is not left running behind it.
  final bool active;

  /// Tests pass their own; otherwise the screen makes and owns one.
  final ScannerViewModel? viewModel;

  const ScannerScreen({super.key, this.active = true, this.viewModel});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with SingleTickerProviderStateMixin {
  late final ScannerViewModel _vm = widget.viewModel ?? ScannerViewModel();
  final _codeController = TextEditingController();
  final MobileScannerController _camera = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    autoStart: false,
  );

  late AnimationController _animController;
  late Animation<double> _laserAnimation;
  bool _isTorchOn = false;

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
    if (widget.active) _startCamera();
  }

  @override
  void didUpdateWidget(covariant ScannerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) {
      widget.active ? _startCamera() : _stopCamera();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _camera.dispose();
    _codeController.dispose();
    if (widget.viewModel == null) _vm.dispose();
    super.dispose();
  }

  Future<void> _startCamera() async {
    try {
      await _camera.start();
    } catch (_) {
      // Permission refused or no camera (emulator): the typed-code field still works.
    }
  }

  Future<void> _stopCamera() async {
    try {
      await _camera.stop();
    } catch (_) {}
    if (mounted) setState(() => _isTorchOn = false);
  }

  void _onDetect(BarcodeCapture capture) {
    final code = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .firstOrNull;
    if (code == null || !_vm.wantsScan(code)) return;
    _lookup(code);
  }

  Future<void> _lookup(String code) async {
    final before = _vm.scanned;
    final error = await _vm.lookup(code, choose: _chooseMatch);
    if (!mounted || error != null) return;
    if (_vm.error != null) {
      HapticFeedback.heavyImpact(); // nothing matched
    } else if (!identical(_vm.scanned, before)) {
      HapticFeedback.mediumImpact(); // a piece was found (not a dismissed "Which one?")
    }
  }

  /// Typed text can match several pieces; a scanned barcode never should.
  Future<VariantItem?> _chooseMatch(List<VariantItem> matches) {
    return showModalBottomSheet<VariantItem>(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                'Which one?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
            ...matches.map(
              (v) => ListTile(
                title: Text(
                  v.productTitle,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  [v.sku, if (v.label.isNotEmpty) v.label].join(' • '),
                ),
                trailing: Text(
                  '${v.quantity} pcs',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                onTap: () => Navigator.of(ctx).pop(v),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _move(bool isStockIn) async {
    final v = _vm.scanned;
    if (v == null) return;
    final done = await showStockMovement(
      context,
      variant: v,
      title: '${v.productTitle} (${v.label})',
      isStockIn: isStockIn,
    );
    // Read the new count back rather than doing the sum here.
    if (done && mounted) _lookup(v.sku.isNotEmpty ? v.sku : v.barcode);
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final canReceive = session.can('inventory:receive');
    final canAdjust = session.can('inventory:adjust');

    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) =>
          _buildScreen(canReceive: canReceive, canAdjust: canAdjust),
    );
  }

  Widget _buildScreen({required bool canReceive, required bool canAdjust}) {
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
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderLight),
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isTorchOn
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                        color: _isTorchOn
                            ? AppColors.accentGold
                            : AppColors.textSecondary,
                        size: 20,
                      ),
                      onPressed: () async {
                        try {
                          await _camera.toggleTorch();
                          setState(() => _isTorchOn = !_isTorchOn);
                        } catch (_) {}
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Typed code, for a tag the camera cannot read (or an emulator with no camera)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _codeController,
                textInputAction: TextInputAction.search,
                onSubmitted: _lookup,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.bgCard,
                  hintText: 'Or type a barcode / SKU',
                  hintStyle: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.keyboard_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(
                      Icons.arrow_forward_rounded,
                      color: AppColors.accentGold,
                      size: 20,
                    ),
                    onPressed: () => _lookup(_codeController.text),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.borderLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.accentGold),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Scanner Viewfinder Area
            Expanded(
              flex: 4,
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
                      Positioned.fill(
                        child: MobileScanner(
                          controller: _camera,
                          onDetect: _onDetect,
                          errorBuilder: (context, error) => Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                error.errorCode ==
                                        MobileScannerErrorCode.permissionDenied
                                    ? 'Camera access is off. Allow it in Settings, or type the code above.'
                                    : 'The camera is not available here. Type the code above.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Gold Corner Brackets for Scanner Framing
                      SizedBox(
                        width: 270,
                        height: 170,
                        child: CustomPaint(
                          painter: ScannerReticlePainter(
                            accentColor: AppColors.accentGold,
                          ),
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
                                    color: AppColors.accentGold.withValues(
                                      alpha: 0.9,
                                    ),
                                    blurRadius: 12,
                                    spreadRadius: 3,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      if (_vm.lookingUp)
                        Container(
                          color: Colors.black45,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFFDE68A),
                            ),
                          ),
                        ),

                      // Hint Text Banner
                      Positioned(
                        bottom: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.crop_free_rounded,
                                size: 14,
                                color: Color(0xFFFDE68A),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Align 50x25mm garment tag inside box',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
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
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  border: const Border(
                    top: BorderSide(color: AppColors.borderLight),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeOutCubic,
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.06),
                        end: Offset.zero,
                      ).animate(a),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(
                      '${_vm.scanned?.id}-${_vm.scanned?.quantity}-${_vm.error}',
                    ),
                    child: LayoutBuilder(
                      builder: (_, box) => SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: box.maxHeight),
                          child: IntrinsicHeight(
                            child: _buildResult(
                              canReceive: canReceive,
                              canAdjust: canAdjust,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult({required bool canReceive, required bool canAdjust}) {
    final v = _vm.scanned;
    final error = _vm.error;
    final recent = _vm.recent;
    if (v == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              error != null
                  ? Icons.search_off_rounded
                  : Icons.qr_code_2_rounded,
              size: 44,
              color: error != null
                  ? AppColors.accentDanger
                  : AppColors.textMuted,
            ),
            const SizedBox(height: 10),
            Text(
              error ?? 'Scan a garment tag to see its stock',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: error != null
                    ? AppColors.accentDanger
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final stockColor = v.isOutOfStock || v.isLowStock
        ? AppColors.accentDanger
        : AppColors.accentSuccess;

    return Column(
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
                border: Border.all(
                  color: AppColors.accentSuccess.withValues(alpha: 0.2),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 13,
                    color: AppColors.accentSuccess,
                  ),
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
            if (v.barcode.isNotEmpty)
              Flexible(
                child: Text(
                  'BARCODE: ${v.barcode}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(
            error,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.accentDanger,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 10),
        Text(
          v.productTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          [v.sku, if (v.label.isNotEmpty) v.label].join(' • '),
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 14),

        // Metrics Strip
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                label: 'Physical Stock',
                value: '${v.quantity}',
                unit: 'units',
                color: stockColor,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricTile(
                label: 'Reorder At',
                value: v.reorderLevel > 0 ? '${v.reorderLevel}' : '—',
                unit: 'units',
                color: AppColors.accentBlue,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: v.averageCost != null
                  ? _buildMetricTile(
                      label: 'You pay',
                      value: formatRupees(v.averageCost!),
                      unit: 'per piece',
                      color: AppColors.accentGold,
                    )
                  : _buildMetricTile(
                      label: 'You sell at',
                      value: v.sellingPrice != null
                          ? formatRupees(v.sellingPrice!)
                          : '—',
                      unit: '',
                      color: AppColors.accentGold,
                    ),
            ),
          ],
        ),

        const SizedBox(height: 10),
        if (SessionScope.of(context).can('shelf:view'))
          Pressable(
            onTap: () => AppRoutes.findPiece(
              context,
              initialQuery: v.sku.isNotEmpty ? v.sku : v.barcode,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.accentGoldLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accentGoldBorder),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shelves, size: 16, color: AppColors.accentGold),
                  SizedBox(width: 8),
                  Text(
                    'Where is it?',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accentGold,
                    ),
                  ),
                  Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.accentGold,
                  ),
                ],
              ),
            ),
          ),
        if (recent.length > 1) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final r in recent.skip(1))
                ActionChip(
                  label: Text(
                    r.sku,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  avatar: const Icon(Icons.history_rounded, size: 14),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: AppColors.bgSurface,
                  side: BorderSide.none,
                  onPressed: () =>
                      _lookup(r.sku.isNotEmpty ? r.sku : r.barcode),
                ),
            ],
          ),
        ],
        const Spacer(),

        // Action Buttons Row
        Row(
          children: [
            if (canReceive)
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add_box_rounded, size: 18),
                  label: const Text('Receive Stock'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentSuccess,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _move(true),
                ),
              ),
            if (canReceive && canAdjust) const SizedBox(width: 12),
            if (canAdjust)
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(
                    Icons.indeterminate_check_box_rounded,
                    size: 18,
                  ),
                  label: const Text('Issue Stock'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accentDanger,
                    side: const BorderSide(color: AppColors.accentDanger),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _move(false),
                ),
              ),
          ],
        ),
      ],
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
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: color,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width - cornerLength, 0),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width, cornerLength),
      paint,
    );

    // Bottom Left
    canvas.drawLine(
      Offset(0, size.height),
      Offset(cornerLength, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height),
      Offset(0, size.height - cornerLength),
      paint,
    );

    // Bottom Right
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width - cornerLength, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width, size.height - cornerLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
