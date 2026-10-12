import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/core/utils/money.dart';
import 'package:scaleezy/core/widgets/ui.dart';
import 'package:scaleezy/features/customers/data/customer_models.dart';

final _count = NumberFormat.decimalPattern('en_IN');
final _date = DateFormat('d MMM yyyy');

/// A customer's loyalty points and store credit, each with its latest changes.
/// Read only: points are changed and credit paid out on the web, and both are
/// spent on the till. The caller shows it only when one of them is given.
class PointsAndCreditSection extends StatelessWidget {
  final CustomerPoints? points;
  final StoreCredit? credit;

  const PointsAndCreditSection({super.key, this.points, this.credit});

  @override
  Widget build(BuildContext context) {
    final p = points;
    final c = credit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Points & store credit'),
        if (p != null)
          _card(
            context,
            icon: Icons.card_giftcard_rounded,
            title: 'Loyalty points',
            amount: _count.format(p.points),
            negative: p.points < 0,
            lines: [
              'points, worth ${formatRupees(p.value)}',
              if (p.lapsesOn != null)
                'Lapse ${_date.format(p.lapsesOn!)} unless they visit',
            ],
            note: p.enabled
                ? null
                : 'Loyalty points are switched off for the shop.',
            entries: p.entries,
            change: (n) => '${n > 0 ? '+' : ''}${_count.format(n)}',
          ),
        if (p != null && c != null) const SizedBox(height: 10),
        if (c != null)
          _card(
            context,
            icon: Icons.account_balance_wallet_rounded,
            title: 'Store credit',
            amount: formatRupees(c.credit),
            negative: c.credit < 0,
            lines: const ['to spend in the shop'],
            entries: c.entries,
            change: (n) => '${n > 0 ? '+' : '−'}${formatRupees(n.abs())}',
          ),
      ],
    );
  }

  Widget _card(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String amount,
    required bool negative,
    required List<String> lines,
    String? note,
    required List<BalanceEntry> entries,
    required String Function(double) change,
  }) {
    final colors = context.colors;
    final type = Theme.of(context).textTheme;
    const tabular = [FontFeature.tabularFigures()];
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colors.brandInk),
              const SizedBox(width: 8),
              Text(title, style: type.titleSmall),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            amount,
            style: type.headlineSmall!.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: tabular,
              color: negative ? colors.danger : colors.text,
            ),
          ),
          for (final line in lines) Text(line, style: type.bodySmall),
          if (note != null) ...[
            const SizedBox(height: 6),
            Text(note, style: type.bodySmall!.copyWith(color: colors.warning)),
          ],
          // The latest five; the full history is on the web.
          for (final e in entries.take(5)) ...[
            const Divider(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.reference == null
                            ? e.label
                            : '${e.label} · ${e.reference}',
                        style: type.bodySmall!.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.text,
                        ),
                      ),
                      Text(
                        e.note == null
                            ? _date.format(e.at)
                            : '${_date.format(e.at)} · ${e.note}',
                        style: type.labelMedium!.copyWith(
                          fontWeight: FontWeight.w400,
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  change(e.change),
                  style: type.titleSmall!.copyWith(
                    fontFeatures: tabular,
                    color: e.change < 0 ? colors.danger : colors.success,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
