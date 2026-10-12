import 'package:flutter/material.dart';

import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/core/widgets/status_pill.dart';

/// A shelf address ("R1-S3") in monospace 700, as the website's `.sh-addr`.
class ShelfAddress extends StatelessWidget {
  final String address;
  final bool big;
  const ShelfAddress(this.address, {super.key, this.big = false});

  @override
  Widget build(BuildContext context) {
    final type = Theme.of(context).textTheme;
    return Text(
      address,
      style: (big ? type.titleLarge : type.titleSmall)!.copyWith(
        fontFamily: 'monospace',
        fontFamilyFallback: const ['Menlo', 'Courier New'],
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    );
  }
}

/// "Shop floor" in success, "Back room" in warning.
class ShelfTag extends StatelessWidget {
  final bool isShopFloor;
  const ShelfTag({super.key, required this.isShopFloor});

  @override
  Widget build(BuildContext context) => isShopFloor
      ? const StatusPill('Shop floor', Tone.success)
      : const StatusPill('Back room', Tone.warning);
}

/// Colour dot, address, name and tag, as the website's `SpotChip`.
class SpotChip extends StatelessWidget {
  final String address;
  final String? name;
  final int? colour;

  /// Null leaves the tag out.
  final bool? isShopFloor;
  final bool big;

  const SpotChip({
    super.key,
    required this.address,
    this.name,
    this.colour,
    this.isShopFloor,
    this.big = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (colour != null)
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: Color(colour!),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: c.borderFocus),
            ),
          ),
        ShelfAddress(address, big: big),
        if (name != null)
          Text(
            name!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        if (isShopFloor != null) ShelfTag(isShopFloor: isShopFloor!),
      ],
    );
  }
}

/// A big count in tabular figures, as the website's `.sh-big-qty`.
class BigQty extends StatelessWidget {
  final String text;
  final Color? color;
  const BigQty(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.titleLarge!.copyWith(
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );
}

/// "1 piece", "3 pieces".
String pieces(int n) => '$n ${n == 1 ? 'piece' : 'pieces'}';
