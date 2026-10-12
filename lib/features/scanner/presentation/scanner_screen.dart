import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:scaleezy/app/app_routes.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/core/utils/money.dart';
import 'package:scaleezy/core/widgets/status_pill.dart';
import 'package:scaleezy/core/widgets/ui.dart';
import 'package:scaleezy/features/inventory/presentation/widgets/stock_movement_dialog.dart';
import 'package:scaleezy/features/products/data/product_models.dart';
import 'package:scaleezy/features/products/presentation/widgets/stock_pill.dart';
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

  /// The camera passes only [code]; typed text, a recent chip and a refresh pass [typed].
  Future<void> _lookup(String code, {bool typed = false}) async {
    final before = _vm.scanned;
    final error = await _vm.lookup(
      code,
      typed: typed,
      choose: _chooseMatch,
      openProduct: (p) => AppRoutes.productDetail(context, p),
    );
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
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Which one?',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            ...matches.map(
              (v) => ListTile(
                title: Text(v.productTitle),
                subtitle: Text(
                  [v.sku, if (v.label.isNotEmpty) v.label].join(' · '),
                ),
                trailing: StockPill(v.quantity, low: v.isLowStock),
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
    if (done && mounted) {
      _lookup(v.sku.isNotEmpty ? v.sku : v.barcode, typed: true);
    }
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
    final c = context.colors;
    final type = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(
              title: 'Scan',
              subtitle: 'Barcode, SKU or QR code on the tag',
              actions: [
                IconButton(
                  tooltip: _isTorchOn ? 'Torch off' : 'Torch on',
                  icon: Icon(
                    _isTorchOn
                        ? Icons.flash_on_rounded
                        : Icons.flash_off_rounded,
                    color: _isTorchOn ? c.brandInk : c.textSecondary,
                  ),
                  onPressed: () async {
                    try {
                      await _camera.toggleTorch();
                      setState(() => _isTorchOn = !_isTorchOn);
                    } catch (_) {}
                  },
                ),
              ],
            ),

            // Typed code, for a tag the camera cannot read (or an emulator with no camera)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _codeController,
                textInputAction: TextInputAction.search,
                onSubmitted: (text) => _lookup(text, typed: true),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Name, SKU or barcode',
                  prefixIcon: const Icon(Icons.keyboard_rounded, size: 20),
                  suffixIcon: IconButton(
                    tooltip: 'Look up',
                    icon: Icon(
                      Icons.arrow_forward_rounded,
                      color: c.brandInk,
                      size: 20,
                    ),
                    onPressed: () => _lookup(_codeController.text, typed: true),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // The camera. Everything drawn over it is a photo overlay: dark glass, light text.
            Expanded(
              flex: 4,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
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
                                    ? 'The camera was not allowed. Turn it on in Settings, or type the code.'
                                    : 'The camera could not be opened. Type the code instead.',
                                textAlign: TextAlign.center,
                                style: type.bodySmall!.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Corner brackets framing the tag
                      SizedBox(
                        width: 270,
                        height: 170,
                        child: CustomPaint(
                          painter: ScannerReticlePainter(accentColor: c.brand),
                        ),
                      ),

                      // Sweeping line
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
                                color: c.brand,
                                boxShadow: [
                                  BoxShadow(
                                    color: tint(c.brand, 0.6),
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
                          child: Center(
                            child: CircularProgressIndicator(color: c.brand),
                          ),
                        ),

                      Positioned(
                        bottom: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.crop_free_rounded,
                                size: 14,
                                color: c.brand,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Point at the barcode',
                                style: type.labelMedium!.copyWith(
                                  color: Colors.white,
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

            // The piece found
            Expanded(
              flex: 6,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  border: Border(top: BorderSide(color: c.border)),
                  boxShadow: c.panelShadow,
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
    final c = context.colors;
    final type = Theme.of(context).textTheme;
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
              size: 40,
              color: error != null ? c.danger : c.textMuted,
            ),
            const SizedBox(height: 10),
            Text(
              error ?? 'Scan a garment tag to see its stock',
              textAlign: TextAlign.center,
              style: type.bodyMedium!.copyWith(
                color: error != null ? c.danger : c.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final stock = stockLook(v.quantity, low: v.isLowStock);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (_vm.exactMatch)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tint(c.success),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 13,
                      color: c.success,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'SKU Match Verified',
                      style: type.labelMedium!.copyWith(color: c.success),
                    ),
                  ],
                ),
              ),
            const Spacer(),
            if (v.barcode.isNotEmpty)
              Flexible(
                flex: 3,
                child: Text(
                  v.barcode,
                  overflow: TextOverflow.ellipsis,
                  style: type.labelMedium!.copyWith(
                    color: c.textMuted,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(error, style: type.labelMedium!.copyWith(color: c.danger)),
        ],
        const SizedBox(height: 10),
        Text(
          v.productTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: type.titleMedium,
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(
              child: Text(
                [v.sku, if (v.label.isNotEmpty) v.label].join(' · '),
                style: type.bodySmall,
              ),
            ),
            StatusPill(stock.label, stock.tone),
          ],
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                label: 'Stock',
                value: '${v.quantity}',
                unit: 'pieces',
                color: c.tone(stock.tone),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricTile(
                label: 'Reorder at',
                value: v.reorderLevel > 0 ? '${v.reorderLevel}' : '—',
                unit: v.reorderLevel > 0 ? 'pieces' : '',
                color: c.text,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: v.costPrice != null
                  ? _buildMetricTile(
                      label: 'You pay',
                      value: formatRupees(v.costPrice!),
                      unit: 'per piece',
                      color: c.text,
                    )
                  : _buildMetricTile(
                      label: 'You sell at',
                      value: v.sellingPrice != null
                          ? formatRupees(v.sellingPrice!)
                          : '—',
                      unit: '',
                      color: c.text,
                    ),
            ),
          ],
        ),

        const SizedBox(height: 10),
        if (SessionScope.of(context).can('shelf:view'))
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => AppRoutes.findPiece(
                context,
                initialQuery: v.sku.isNotEmpty ? v.sku : v.barcode,
              ),
              icon: const Icon(Icons.shelves, size: 16),
              label: const Text('Where is it?'),
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
                  label: Text(r.sku),
                  avatar: const Icon(Icons.history_rounded, size: 14),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _lookup(
                    r.sku.isNotEmpty ? r.sku : r.barcode,
                    typed: true,
                  ),
                ),
            ],
          ),
        ],
        const Spacer(),

        Row(
          children: [
            if (canReceive)
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.add_box_rounded, size: 18),
                  label: const Text('Receive stock'),
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
                  label: const Text('Issue stock'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.danger,
                    side: BorderSide(color: tint(c.danger, 0.5)),
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
    final c = context.colors;
    final type = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.input,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: type.labelSmall,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: type.titleMedium!.copyWith(
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (unit.isNotEmpty)
            Text(unit, style: type.labelMedium!.copyWith(color: c.textMuted)),
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
