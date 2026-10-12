import 'package:flutter/material.dart';

/// The Scaleezy wordmark. On a dark theme it sits on a white rounded plate, because its dark
/// green half is unreadable on black.
class BrandLogo extends StatelessWidget {
  final double height;
  const BrandLogo({super.key, this.height = 34});

  @override
  Widget build(BuildContext context) {
    final logo = Image.asset(
      'assets/brand/scaleezy-logo.png',
      height: height,
      fit: BoxFit.contain,
      semanticLabel: 'Scaleezy',
    );
    if (Theme.of(context).brightness == Brightness.light) return logo;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: logo,
    );
  }
}
