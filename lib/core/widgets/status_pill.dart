import 'package:flutter/material.dart';
import 'package:scaleezy/core/theme/app_theme.dart';

/// A sentence-case status in its tone, on the tone at 12%. Look a status up with
/// `describeStatus` from `core/theme/status_tones.dart`.
class StatusPill extends StatelessWidget {
  final String label;
  final Tone tone;
  final bool large;
  const StatusPill(this.label, this.tone, {super.key, this.large = false});

  @override
  Widget build(BuildContext context) {
    final color = context.colors.tone(tone);
    return Container(
      padding: large
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 4)
          : const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tint(color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: Theme.of(context).textTheme.labelMedium!.copyWith(
          fontSize: large ? 13 : 12,
          color: color,
        ),
      ),
    );
  }
}
