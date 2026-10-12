import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/core/widgets/no_access_screen.dart';

/// Three bouncing dots and an optional caps label, like the website's page loader.
class LoadingView extends StatelessWidget {
  final String? message;
  const LoadingView({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++)
                Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: c.textSecondary,
                        shape: BoxShape.circle,
                      ),
                    )
                    .animate(
                      delay: (150 * i).ms,
                      onPlay: (a) => a.repeat(reverse: true),
                    )
                    .fade(begin: 0.4, end: 1, duration: 400.ms)
                    .moveY(begin: 0, end: -6, curve: Curves.easeInOut),
            ],
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall!.copyWith(
                fontSize: 12,
                color: c.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Nothing to show: a muted icon, a title and an optional line of help.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? text;
  const EmptyState(this.icon, this.title, {super.key, this.text});

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
            Icon(icon, size: 40, color: c.textMuted),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: type.titleMedium!.copyWith(fontSize: 17),
            ),
            if (text != null) ...[
              const SizedBox(height: 6),
              Text(
                text!,
                textAlign: TextAlign.center,
                style: type.bodyMedium!.copyWith(color: c.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A load that failed, as the website's `LoadFailed`: danger triangle, "Could not load [what]."
/// over the server's [message], the reassurance and "Try again". A 403 [error] shows
/// [NoAccessView] instead (nothing to retry). Without [onRetry] or [what] it is a plain empty
/// message, as older callers use it; new empty lists use [EmptyState].
class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  /// What was being loaded, e.g. "customers": the heading reads "Could not load customers."
  final String? what;

  /// The failure itself; a 403 [ApiException] turns this into [NoAccessView].
  final Object? error;

  const ErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.what,
    this.error,
  });

  /// From a caught error: its message when it is an [ApiException], the website's sentence
  /// otherwise.
  ErrorView.fromError(Object this.error, {super.key, this.what, this.onRetry})
    : message = error is ApiException
          ? error.message
          : 'Something went wrong reaching the server.';

  @override
  Widget build(BuildContext context) {
    final failure = error;
    if (failure is ApiException && failure.isForbidden) {
      return NoAccessView(message: failure.message);
    }
    if (onRetry == null && what == null) {
      return EmptyState(Icons.inbox_outlined, message);
    }
    final c = context.colors;
    final type = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, size: 40, color: c.danger),
            const SizedBox(height: 12),
            Text(
              what == null ? message : 'Could not load $what.',
              textAlign: TextAlign.center,
              style: type.titleSmall,
            ),
            if (what != null) ...[
              const SizedBox(height: 6),
              Text(message, textAlign: TextAlign.center, style: type.bodySmall),
            ],
            const SizedBox(height: 6),
            Text(
              'This is not the same as having none — nothing has been lost.',
              textAlign: TextAlign.center,
              style: type.bodySmall,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A floating toast on the card colour; a green tick for [success] (2 s), a red mark for [error]
/// (4 s).
void showMessage(
  BuildContext context,
  String message, {
  bool error = false,
  bool success = false,
}) {
  final c = context.colors;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: c.card,
      duration: Duration(seconds: success && !error ? 2 : 4),
      content: Row(
        children: [
          if (error || success) ...[
            Icon(
              error ? Icons.error_rounded : Icons.check_circle_rounded,
              size: 20,
              color: error ? c.danger : c.success,
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(message, style: TextStyle(color: c.text)),
          ),
        ],
      ),
    ),
  );
}
