import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:scaleezy/core/theme/app_theme.dart';

/// Opens the camera in a sheet. Single mode returns the first code read. Continuous mode calls
/// [onCode] for every new code (return a short message to flash, e.g. "+1 Red saree") and closes
/// on Done. A typed code works in both, for tags the camera cannot read.
Future<String?> showScanSheet(
  BuildContext context, {
  required String title,
  String hint = 'Point the camera at the barcode',
  Future<String?> Function(String code)? onCode,
}) {
  return showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ScanSheet(title: title, hint: hint, onCode: onCode),
  );
}

class _ScanSheet extends StatefulWidget {
  final String title;
  final String hint;
  final Future<String?> Function(String code)? onCode;

  const _ScanSheet({required this.title, required this.hint, this.onCode});

  @override
  State<_ScanSheet> createState() => _ScanSheetState();
}

class _ScanSheetState extends State<_ScanSheet> {
  final _camera = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
  );
  final _typed = TextEditingController();
  String? _last;
  DateTime _lastAt = DateTime(0);
  String? _flash;
  int _flashId = 0;
  bool _busy = false;

  bool get _continuous => widget.onCode != null;

  @override
  void dispose() {
    _camera.dispose();
    _typed.dispose();
    super.dispose();
  }

  Future<void> _handle(String raw) async {
    final code = raw.trim();
    if (code.isEmpty || _busy) return;
    // The same tag held in view reads many times a second; count it again only after a pause.
    final now = DateTime.now();
    if (code == _last &&
        now.difference(_lastAt) < const Duration(milliseconds: 1500)) {
      return;
    }
    _last = code;
    _lastAt = now;
    HapticFeedback.mediumImpact();

    if (!_continuous) {
      Navigator.of(context).pop(code);
      return;
    }
    setState(() => _busy = true);
    final message = await widget.onCode!(code);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _flash = message;
      _flashId++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.78 + bottom,
      padding: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (_continuous)
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.textPrimary,
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    )
                  else
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: Colors.black),
                      MobileScanner(
                        controller: _camera,
                        onDetect: (capture) {
                          final code = capture.barcodes
                              .map((b) => b.rawValue)
                              .whereType<String>()
                              .firstOrNull;
                          if (code != null) _handle(code);
                        },
                        errorBuilder: (_, error) => Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              error.errorCode ==
                                      MobileScannerErrorCode.permissionDenied
                                  ? 'Camera access is off. Allow it in Settings, or type the code below.'
                                  : 'No camera here. Type the code below.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child:
                            Container(
                                  width: 240,
                                  height: 150,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: const Color(0xFFFDE68A),
                                      width: 2.5,
                                    ),
                                  ),
                                )
                                .animate(onPlay: (c) => c.repeat(reverse: true))
                                .scaleXY(
                                  begin: 1,
                                  end: 1.04,
                                  duration: 1100.ms,
                                  curve: Curves.easeInOut,
                                ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 16,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              widget.hint,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_flash != null)
                        Positioned(
                          top: 16,
                          left: 16,
                          right: 16,
                          child:
                              Container(
                                    key: ValueKey(_flashId),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text(
                                      _flash!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                    ),
                                  )
                                  .animate(key: ValueKey(_flashId))
                                  .fadeIn(duration: 150.ms)
                                  .scaleXY(
                                    begin: 0.9,
                                    end: 1,
                                    curve: Curves.easeOutBack,
                                  )
                                  .then(delay: 1500.ms)
                                  .fadeOut(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: TextField(
                controller: _typed,
                textInputAction: TextInputAction.done,
                onSubmitted: (v) {
                  _last = null;
                  _handle(v);
                  _typed.clear();
                },
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.bgSurface,
                  hintText: 'Or type the code',
                  prefixIcon: const Icon(Icons.keyboard_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: const Icon(
                      Icons.arrow_forward_rounded,
                      color: AppColors.accentGold,
                    ),
                    onPressed: () {
                      _last = null;
                      _handle(_typed.text);
                      _typed.clear();
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
