import 'package:flutter/material.dart';

import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/core/utils/permission_text.dart';

/// "This isn't for you", said calmly, as the website's `NoAccess`: a muted lock, no red and
/// nothing to retry. The heading is "You cannot [what]" (or "Not part of your role"); the line
/// is [message] (a 403's own sentence) or the ask for [permission].
class NoAccessView extends StatelessWidget {
  final String? what;
  final String? permission;
  final String? message;

  /// A way out to a page the person can open; only the full-page version has one.
  final VoidCallback? onLeave;

  const NoAccessView({
    super.key,
    this.what,
    this.permission,
    this.message,
    this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final type = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: c.input, shape: BoxShape.circle),
              child: Icon(
                Icons.lock_outline_rounded,
                size: 20,
                color: c.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              noAccessTitle(what),
              textAlign: TextAlign.center,
              style: type.titleLarge,
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                message ?? noAccessMessage(permission),
                textAlign: TextAlign.center,
                style: type.bodyMedium!.copyWith(
                  color: c.textMuted,
                  height: 1.5,
                ),
              ),
            ),
            if (onLeave != null) ...[
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: onLeave,
                child: const Text('Go to a page you can open'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shown in place of a screen the role cannot open, as the web's `<Guard>` does: the address
/// stays, and [onLeave] goes to the first page the person can open.
class NoAccessScreen extends StatelessWidget {
  final String? what;
  final String? permission;
  final VoidCallback? onLeave;

  const NoAccessScreen({super.key, this.what, this.permission, this.onLeave});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: NoAccessView(
          what: what,
          permission: permission,
          onLeave: onLeave,
        ),
      ),
    );
  }
}
