import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/core/utils/contact_utils.dart';
import 'package:scaleezy/core/widgets/async_state.dart';
import 'package:scaleezy/core/widgets/ui.dart';
import 'package:scaleezy/features/orders/presentation/view_models/receipt_view_model.dart';

/// A counter bill as the web's receipt shows it, with a WhatsApp share. No print, no PDF.
class ReceiptScreen extends StatefulWidget {
  final String orderId;

  /// Tests pass their own; otherwise the screen makes and owns one.
  final ReceiptViewModel? viewModel;

  const ReceiptScreen({super.key, required this.orderId, this.viewModel});

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  late final ReceiptViewModel _vm =
      widget.viewModel ?? ReceiptViewModel(widget.orderId);

  static const _paperText = TextStyle(
    fontFamily: 'monospace',
    fontSize: 12,
    height: 1.35,
    color: Colors.black,
  );

  @override
  void initState() {
    super.initState();
    _vm.load();
  }

  @override
  void dispose() {
    if (widget.viewModel == null) _vm.dispose();
    super.dispose();
  }

  /// To the customer's own chat when the bill has a number; otherwise WhatsApp asks who.
  Future<void> _share() {
    final number = _vm.shareNumber;
    return launchContact(
      context,
      Uri.parse(
        'https://wa.me/${number == null ? '' : whatsappNumber(number)}'
        '?text=${Uri.encodeComponent(_vm.shareText)}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => _buildScreen(),
    );
  }

  Widget _buildScreen() {
    final r = _vm.receipt;
    final error = _vm.error;
    final printable = r != null && r.atCounter;

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      bottomNavigationBar: printable
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: FilledButton.icon(
                  onPressed: _share,
                  icon: const Icon(Icons.chat_rounded),
                  label: const Text(
                    'Share on WhatsApp',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accentGold,
          onRefresh: _vm.load,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              PageHeader(title: 'Receipt', subtitle: r?.orderNumber),
              if (r == null && error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 80),
                  child: ErrorView(message: error, onRetry: _vm.load),
                )
              else if (r == null)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Skeleton(height: 420, radius: 22),
                )
              else if (!r.atCounter)
                // The till prints its own bills; a counter receipt for one would end in a false "Due".
                ErrorView(
                  message:
                      'Receipts here are for bills made at Inventory\'s own counter. '
                      'Order ${r.orderNumber} was not sold there — a bill made on the '
                      'POS till is printed by the till.',
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: _paper(r.logoUrl).entrance(0),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// White paper, black ink and a typewriter face, like the printed 80 mm receipt.
  Widget _paper(String? logoUrl) {
    final header = _vm.header;
    Widget rule() => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        '-' * 80,
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: _paperText.copyWith(color: Colors.black54),
      ),
    );
    Widget row(ReceiptRow r) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              r.left,
              style: _paperText.copyWith(
                fontWeight: r.bold ? FontWeight.w700 : null,
                fontSize: r.muted ? 11 : null,
                color: r.muted ? Colors.black54 : null,
              ),
            ),
          ),
          if (r.right.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              r.right,
              style: _paperText.copyWith(
                fontWeight: r.bold ? FontWeight.w700 : null,
                fontSize: r.bold ? 14 : null,
              ),
            ),
          ],
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: AppColors.elevatedShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (logoUrl != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: CachedNetworkImage(
                imageUrl: logoUrl,
                height: 48,
                fit: BoxFit.contain,
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          for (final (i, line) in header.indexed)
            Text(
              line,
              textAlign: TextAlign.center,
              style: i == 0
                  ? _paperText.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    )
                  : line == 'DUPLICATE'
                  ? _paperText.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    )
                  : _paperText.copyWith(fontSize: 11),
            ),
          rule(),
          ..._vm.meta.map(row),
          rule(),
          ..._vm.lines.map(row),
          rule(),
          ..._vm.totals.map(row),
          rule(),
          for (final line in _vm.footer)
            Text(
              line,
              textAlign: TextAlign.center,
              style: _paperText.copyWith(fontSize: 11),
            ),
        ],
      ),
    );
  }
}
