import 'package:flutter/material.dart';

import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/core/widgets/brand_logo.dart';
import 'package:scaleezy/features/auth/presentation/view_models/login_view_model.dart';

/// Signing in, in the website's `AuthShell` frame (one column, as the web shows on a phone):
/// the wordmark, what this is, and a card with the fields. Problems show above the button.
class LoginScreen extends StatefulWidget {
  /// Tests pass their own; otherwise the screen makes and owns one.
  final LoginViewModel? viewModel;

  const LoginScreen({super.key, this.viewModel});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final LoginViewModel _vm =
      widget.viewModel ?? LoginViewModel(SessionScope.read(context));
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _forgotOpen = false;

  @override
  void dispose() {
    if (widget.viewModel == null) _vm.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit({String? clientId}) async {
    FocusScope.of(context).unfocus();
    await _vm.submit(
      _emailController.text,
      _passwordController.text,
      clientId: clientId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final type = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _vm,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 48),
            children: [
              const Align(alignment: Alignment.centerLeft, child: BrandLogo()),
              const SizedBox(height: 32),
              Text(
                'WELCOME BACK',
                textAlign: TextAlign.center,
                style: type.labelSmall!.copyWith(
                  color: c.brandInk,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Sign in to your shop',
                textAlign: TextAlign.center,
                style: type.headlineMedium!.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your stock, your costs and your margins, exactly where you left them.',
                textAlign: TextAlign.center,
                style: type.bodyLarge!.copyWith(
                  color: c.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: c.card,
                      border: Border.all(color: c.border),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: c.panelShadow,
                    ),
                    child: _vm.workspaceChoice == null
                        ? _form(context)
                        : _workspaces(context, _vm.workspaceChoice!),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall!.copyWith(
        color: context.colors.textMuted,
        letterSpacing: 1,
      ),
    ),
  );

  Widget _form(BuildContext context) {
    final c = context.colors;
    final type = Theme.of(context).textTheme;
    final busy = _vm.submitting;
    final error = _vm.error;
    final field = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c.border),
    );
    InputDecoration decoration(
      String hint, {
      Widget? suffix,
    }) => InputDecoration(
      hintText: hint,
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: field,
      enabledBorder: field,
      focusedBorder: field.copyWith(borderSide: BorderSide(color: c.brandInk)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label(context, 'Email address'),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.next,
          enabled: !busy,
          decoration: decoration('you@yourshop.com'),
        ),
        const SizedBox(height: 20),
        _label(context, 'Password'),
        TextField(
          controller: _passwordController,
          obscureText: _obscure,
          autofillHints: const [AutofillHints.password],
          textInputAction: TextInputAction.done,
          enabled: !busy,
          onSubmitted: (_) => _submit(),
          decoration: decoration(
            'Your password',
            suffix: IconButton(
              tooltip: _obscure ? 'Show password' : 'Hide password',
              icon: Icon(
                _obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20,
                color: c.textMuted,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: tint(c.danger),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: tint(c.danger, 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline_rounded, size: 17, color: c.danger),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    error,
                    style: type.bodyMedium!.copyWith(
                      color: c.danger,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: busy ? null : () => _submit(),
          style: FilledButton.styleFrom(
            backgroundColor: c.brandSolid,
            foregroundColor: c.onBrandSolid,
            disabledBackgroundColor: tint(c.brandSolid, 0.75),
            disabledForegroundColor: c.onBrandSolid,
            minimumSize: const Size.fromHeight(54),
            shape: const StadiumBorder(),
            textStyle: type.titleMedium!.copyWith(fontWeight: FontWeight.w700),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy) ...[
                SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: c.onBrandSolid,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Text(busy ? 'Signing in…' : 'Sign in'),
              if (!busy) ...[
                const SizedBox(width: 10),
                const Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ],
          ),
        ),
        if (busy) ...[
          const SizedBox(height: 12),
          Text(
            'The server can take a little while to answer. Hang on.',
            textAlign: TextAlign.center,
            style: type.labelMedium!.copyWith(color: c.textMuted),
          ),
        ],
        const SizedBox(height: 16),
        // No self-service reset: the owner or an admin sets passwords. Saying so beats
        // trying passwords until the sign-in is rate-limited.
        TextButton(
          onPressed: () => setState(() => _forgotOpen = !_forgotOpen),
          style: TextButton.styleFrom(foregroundColor: c.textSecondary),
          child: const Text('Forgot your password?'),
        ),
        if (_forgotOpen)
          Text(
            'Ask your shop owner or manager. They can set a new one for you in '
            'Settings → Team members.',
            textAlign: TextAlign.center,
            style: type.bodyMedium!.copyWith(
              color: c.textSecondary,
              height: 1.6,
            ),
          ),
      ],
    );
  }

  Widget _workspaces(BuildContext context, WorkspaceChoiceRequired choice) {
    final c = context.colors;
    final type = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'This email is used in more than one shop. Choose which one to sign into.',
          style: type.bodyLarge!.copyWith(color: c.textSecondary, height: 1.6),
        ),
        const SizedBox(height: 14),
        for (final id in choice.clientIds) ...[
          OutlinedButton.icon(
            onPressed: _vm.submitting ? null : () => _submit(clientId: id),
            icon: Icon(Icons.business_rounded, size: 18, color: c.brandInk),
            label: Text(id),
            style: OutlinedButton.styleFrom(
              backgroundColor: c.input,
              alignment: Alignment.centerLeft,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        TextButton(
          onPressed: _vm.cancelWorkspaceChoice,
          style: TextButton.styleFrom(foregroundColor: c.textSecondary),
          child: const Text('← Back'),
        ),
      ],
    );
  }
}
