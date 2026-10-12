import 'package:flutter/widgets.dart';

import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/core/theme/status_tones.dart';
import 'package:scaleezy/core/widgets/status_pill.dart';

/// The website's stock words (`ProductGrid.jsx`, `VariantTable.jsx`): below zero is said
/// outright, zero is out, then low, then the count. Negative stock is never green.
StatusLook stockLook(int units, {bool low = false}) => units < 0
    ? (label: '$units · oversold', tone: Tone.danger)
    : units == 0
    ? (label: 'Out of stock', tone: Tone.danger)
    : low
    ? (label: 'Low stock', tone: Tone.warning)
    : (label: '$units in stock', tone: Tone.success);

/// [stockLook] as a pill.
class StockPill extends StatelessWidget {
  final int units;
  final bool low;
  const StockPill(this.units, {super.key, this.low = false});

  @override
  Widget build(BuildContext context) {
    final look = stockLook(units, low: low);
    return StatusPill(look.label, look.tone);
  }
}
