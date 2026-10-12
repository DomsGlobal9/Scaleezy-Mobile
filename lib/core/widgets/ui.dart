import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:scaleezy/core/theme/app_theme.dart';

/// Entrance used across the app: fade + rise, staggered by [index].
extension EntranceAnimate on Widget {
  Widget entrance(int index, {double rise = 14}) =>
      animate(delay: (40 * math.min(index, 12)).ms)
          .fadeIn(duration: 380.ms, curve: Curves.easeOutCubic)
          .moveY(
            begin: rise,
            end: 0,
            duration: 460.ms,
            curve: Curves.easeOutCubic,
          );
}

/// A grey block that shimmers while real content loads -- the shape of what is coming.
class Skeleton extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const Skeleton({
    super.key,
    this.width,
    required this.height,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(radius),
          ),
        )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1400.ms, color: Colors.white.withValues(alpha: 0.7));
  }
}

/// Counts up to [value] whenever it changes.
class AnimatedCount extends StatelessWidget {
  final num value;
  final String Function(num) format;
  final TextStyle? style;

  const AnimatedCount({
    super.key,
    required this.value,
    required this.format,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => Text(
        // Integers stay integers while counting; money keeps its paise at the end.
        format(value is int ? v.round() : (v == value ? value : v)),
        style: style,
      ),
    );
  }
}

/// A photograph from the server, cached, with a shimmer while it loads and a garment icon when
/// there is none.
class NetImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final double radius;
  final IconData fallbackIcon;

  const NetImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.radius = 14,
    this.fallbackIcon = Icons.checkroom_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFBEB), Color(0xFFF1F5F9)],
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(
        fallbackIcon,
        color: AppColors.accentGold.withValues(alpha: 0.55),
        size: 26,
      ),
    );
    if (url == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: url!,
        width: width,
        height: height,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 250),
        placeholder: (_, _) =>
            Skeleton(width: width, height: height ?? 80, radius: radius),
        errorWidget: (_, _, _) => fallback,
      ),
    );
  }
}

/// Shrinks a touch under the finger and gives a light tick -- things feel pressable.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  final VoidCallback? onTrailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.onTrailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ),
          if (trailing != null)
            GestureDetector(
              onTap: onTrailing,
              child: Text(
                trailing!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentGold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "just now", "12 min ago", "3 h ago", "yesterday", "4 Sep".
String relativeTime(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  if (d.inDays == 1) return 'yesterday';
  if (d.inDays < 7) return '${d.inDays} days ago';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${t.day} ${months[t.month - 1]}';
}

/// One day's pieces in and out.
class DayFlow {
  final DateTime day;
  final int inQty;
  final int outQty;
  const DayFlow(this.day, this.inQty, this.outQty);
}

/// Paired bars per day, growing in from zero.
class FlowChart extends StatelessWidget {
  final List<DayFlow> days;
  final double height;

  const FlowChart({super.key, required this.days, this.height = 120});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, t, _) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _FlowPainter(days, t)),
      ),
    );
  }
}

class _FlowPainter extends CustomPainter {
  final List<DayFlow> days;
  final double t;
  _FlowPainter(this.days, this.t);

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty) return;
    const labelH = 18.0;
    final chartH = size.height - labelH;
    final peak = days.fold<int>(
      1,
      (m, d) => math.max(m, math.max(d.inQty, d.outQty)),
    );
    final slot = size.width / days.length;
    final barW = math.min(10.0, slot / 4);
    final inPaint = Paint()..color = const Color(0xFF34D399);
    final outPaint = Paint()..color = const Color(0xFFFDA4AF);
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;

    for (var g = 1; g <= 3; g++) {
      final y = chartH * g / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (var i = 0; i < days.length; i++) {
      final cx = slot * i + slot / 2;
      final d = days[i];
      void bar(int qty, double x, Paint p) {
        final h = qty == 0 ? 2.0 : math.max(4.0, chartH * qty / peak * t);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, chartH - h, barW, h),
            const Radius.circular(4),
          ),
          qty == 0
              ? (Paint()..color = Colors.white.withValues(alpha: 0.12))
              : p,
        );
      }

      bar(d.inQty, cx - barW - 1.5, inPaint);
      bar(d.outQty, cx + 1.5, outPaint);

      final isToday = DateUtils.isSameDay(d.day, DateTime.now());
      final tp = TextPainter(
        text: TextSpan(
          text: _labels[d.day.weekday - 1],
          style: TextStyle(
            fontSize: 10,
            fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
            color: isToday ? const Color(0xFFFDE68A) : const Color(0xFF94A3B8),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, chartH + 5));
    }
  }

  @override
  bool shouldRepaint(covariant _FlowPainter old) =>
      old.t != t || old.days != days;
}

/// PURCHASE_RECEIPT -> "Purchase receipt".
String reasonLabel(String reason) {
  final words = reason
      .toLowerCase()
      .split('_')
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return 'Movement';
  return [
    words.first[0].toUpperCase() + words.first.substring(1),
    ...words.skip(1),
  ].join(' ');
}

/// Large title for a pushed module page, with a back button and optional actions.
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  /// Instead of a plain pop, e.g. to pop a result.
  final VoidCallback? onBack;

  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          if (canPop)
            IconButton(
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded),
            )
          else
            const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                  ),
                ),
                if (subtitle != null)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      subtitle!,
                      key: ValueKey(subtitle),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

class SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  const SearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.bgCard,
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.textSecondary,
          size: 20,
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                  onClear?.call();
                },
              ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.accentGold, width: 1.5),
        ),
      ),
    );
  }
}

/// − n + with long-press-free big targets; [max] caps it (e.g. pieces outstanding).
class QuantityStepper extends StatelessWidget {
  final int value;
  final int min;
  final int? max;
  final ValueChanged<int> onChanged;

  const QuantityStepper({
    super.key,
    required this.value,
    this.min = 0,
    this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, int next, bool enabled) => Pressable(
      onTap: enabled ? () => onChanged(next) : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: enabled ? AppColors.bgSurface : AppColors.bgLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? AppColors.textPrimary : AppColors.textMuted,
        ),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        btn(Icons.remove_rounded, value - 1, value > min),
        SizedBox(
          width: 44,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: Text(
              '$value',
              key: ValueKey(value),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
        ),
        btn(Icons.add_rounded, value + 1, max == null || value < max!),
      ],
    );
  }
}

/// A yes/no question before anything that is hard to undo.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool danger = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
      ),
      content: Text(
        message,
        style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: danger
                ? AppColors.accentDanger
                : AppColors.accentGold,
          ),
          child: Text(
            confirmLabel,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
  return ok == true;
}

/// A white rounded card, the app's basic surface.
class SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: AppColors.cardShadow,
      ),
      child: child,
    );
    return onTap == null ? card : Pressable(onTap: onTap, child: card);
  }
}

String initialsOf(String text) {
  final parts = text
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '•';
  return parts.take(2).map((p) => p[0].toUpperCase()).join();
}
