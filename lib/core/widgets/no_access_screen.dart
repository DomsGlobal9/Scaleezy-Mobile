import 'package:flutter/material.dart';
import 'package:scaleezy/core/theme/app_theme.dart';

/// Shown in place of a screen the role cannot open, as the web's `<Guard>` does: the address
/// stays, and [onLeave] goes to the first page the person can open.
class NoAccessScreen extends StatelessWidget {
  final String what;
  final VoidCallback? onLeave;

  const NoAccessScreen({super.key, required this.what, this.onLeave});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 44,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 12),
              Text(
                'Your role does not include $what. Ask the shop owner if you need it.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (onLeave != null) ...[
                const SizedBox(height: 14),
                OutlinedButton(
                  onPressed: onLeave,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.borderLight),
                  ),
                  child: const Text('Go to a page you can open'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
