import 'package:flutter/material.dart';

import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/shop/shop_context.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/core/widgets/async_state.dart';
import 'package:scaleezy/core/widgets/ui.dart';
import 'package:scaleezy/features/settings/presentation/view_models/password_view_model.dart';
import 'package:scaleezy/features/settings/presentation/view_models/settings_view_model.dart';

class SettingsScreen extends StatefulWidget {
  /// Tests pass their own; otherwise the screen makes and owns one.
  final SettingsViewModel? viewModel;

  const SettingsScreen({super.key, this.viewModel});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsViewModel _vm =
      widget.viewModel ??
      SettingsViewModel(SessionScope.read(context), ShopScope.read(context));

  @override
  void dispose() {
    if (widget.viewModel == null) _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final shop = ShopScope.of(context);
    final user = session.user;
    final b = shop.branding;

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            const PageHeader(title: 'Settings'),
            _section('Profile and shop details', [
              _tile(
                context,
                Icons.badge_outlined,
                'Name',
                user?.name ?? '',
                onTap: () => _editText(
                  context,
                  title: 'Your name',
                  initial: user?.name ?? '',
                  save: _vm.saveName,
                ),
              ),
              _tile(
                context,
                Icons.alternate_email_rounded,
                'Email',
                user?.email ?? '',
              ),
              _tile(
                context,
                Icons.verified_user_outlined,
                'Role',
                (user?.roles ?? const []).join(', '),
              ),
            ]).entrance(0),
            _section('Security', [
              _tile(
                context,
                Icons.lock_outline_rounded,
                'Change password',
                'At least 8 characters',
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: AppColors.bgCard,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(26),
                    ),
                  ),
                  builder: (_) => const _PasswordSheet(),
                ),
              ),
              _tile(
                context,
                Icons.devices_other_rounded,
                'Sign out other devices',
                'Keeps you signed in here',
                onTap: () async {
                  final ok = await confirmAction(
                    context,
                    title: 'Sign out everywhere else?',
                    message:
                        'Every other phone and browser signed in as you will have to sign in again.',
                    confirmLabel: 'Sign them out',
                  );
                  if (!ok || !context.mounted) return;
                  final error = await _vm.signOutOtherDevices();
                  if (!context.mounted) return;
                  if (error == null) {
                    showMessage(
                      context,
                      'Signed out of every other device.',
                      success: true,
                    );
                  } else {
                    showMessage(context, error, error: true);
                  }
                },
              ),
            ]).entrance(1),
            _section(user?.isOwner == true ? 'Shop (you can edit)' : 'Shop', [
              _tile(
                context,
                Icons.storefront_outlined,
                'Shop name',
                b.businessName ?? 'Not set',
                onTap: user?.isOwner == true
                    ? () => _editText(
                        context,
                        title: 'Shop name',
                        initial: b.businessName ?? '',
                        save: _vm.saveShopName,
                      )
                    : null,
              ),
              _tile(
                context,
                Icons.call_outlined,
                'Shop phone',
                b.businessPhone ?? 'Not set',
                onTap: user?.isOwner == true
                    ? () => _editText(
                        context,
                        title: 'Shop phone',
                        initial: b.businessPhone ?? '',
                        keyboard: TextInputType.phone,
                        save: _vm.saveShopPhone,
                      )
                    : null,
              ),
              _tile(
                context,
                Icons.place_outlined,
                'Address',
                b.businessAddress ?? 'Not set',
                onTap: user?.isOwner == true
                    ? () => _editText(
                        context,
                        title: 'Shop address',
                        initial: b.businessAddress ?? '',
                        lines: 3,
                        save: _vm.saveShopAddress,
                      )
                    : null,
              ),
              _tile(
                context,
                Icons.fingerprint_rounded,
                'Shop ID',
                user?.clientId ?? '',
              ),
              _tile(
                context,
                Icons.layers_outlined,
                'Stores',
                shop.locations.isEmpty
                    ? 'None'
                    : shop.locations.map((l) => l.name).join(', '),
              ),
            ]).entrance(2),
            _section('App', [
              _tile(context, Icons.cloud_outlined, 'Server', _vm.serverHost),
            ]).entrance(3),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: OutlinedButton.icon(
                onPressed: () async {
                  if (await confirmAction(
                    context,
                    title: 'Sign out?',
                    message:
                        'You will need your email and password to come back in.',
                    confirmLabel: 'Sign out',
                  )) {
                    await _vm.signOut();
                    if (context.mounted) {
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    }
                  }
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text(
                  'Sign out',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accentDanger,
                  side: BorderSide(
                    color: AppColors.accentDanger.withValues(alpha: 0.3),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ).entrance(4),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> tiles) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textMuted,
              letterSpacing: 0.8,
            ),
          ),
        ),
        SurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (i, t) in tiles.indexed) ...[
                if (i > 0) const Divider(height: 1, indent: 56),
                t,
              ],
            ],
          ),
        ),
      ],
    ),
  );

  Widget _tile(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    VoidCallback? onTap,
  }) => ListTile(
    onTap: onTap,
    leading: Icon(icon, color: AppColors.textSecondary),
    title: Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        color: AppColors.textMuted,
        fontWeight: FontWeight.w600,
      ),
    ),
    subtitle: Text(
      value,
      style: const TextStyle(
        fontSize: 14,
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
    ),
    trailing: onTap == null
        ? null
        : const Icon(
            Icons.edit_outlined,
            size: 18,
            color: AppColors.accentGold,
          ),
  );

  Future<void> _editText(
    BuildContext context, {
    required String title,
    required String initial,
    required Future<String?> Function(String) save,
    TextInputType keyboard = TextInputType.text,
    int lines = 1,
  }) async {
    // Not disposed: the sheet still builds the field while it animates closed after the
    // await below returns; nothing else holds it, so it is simply collected.
    final controller = TextEditingController(text: initial);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) {
        String? error; // the last save's message, shown under the field
        return StatefulBuilder(
          builder: (ctx, set) => Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              18,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: lines > 1 ? TextInputType.multiline : keyboard,
                  maxLines: lines,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.bgSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    error!,
                    style: const TextStyle(
                      color: AppColors.accentDanger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                ListenableBuilder(
                  listenable: _vm,
                  builder: (_, _) => FilledButton(
                    onPressed: _vm.saving
                        ? null
                        : () async {
                            set(() => error = null);
                            final message = await save(controller.text.trim());
                            if (message != null) {
                              if (ctx.mounted) set(() => error = message);
                              return;
                            }
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            if (context.mounted) {
                              showMessage(context, 'Saved.', success: true);
                            }
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accentGold,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _vm.saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PasswordSheet extends StatefulWidget {
  const _PasswordSheet();

  @override
  State<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<_PasswordSheet> {
  final _vm = PasswordViewModel();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _again = TextEditingController();
  bool _show = false;

  @override
  void dispose() {
    _vm.dispose();
    _current.dispose();
    _next.dispose();
    _again.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final error = await _vm.change(_current.text, _next.text, _again.text);
    if (error != null || !mounted) return;
    Navigator.of(context).pop();
    showMessage(
      context,
      'Password changed. Other devices have been signed out.',
      success: true,
    );
  }

  Widget _field(TextEditingController c, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: c,
      obscureText: !_show,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.bgSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => _buildSheet(),
    );
  }

  Widget _buildSheet() {
    final error = _vm.error;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Change password',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _show = !_show),
                icon: Icon(
                  _show
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _field(_current, 'Current password'),
          _field(_next, 'New password'),
          _field(_again, 'New password again'),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                error,
                style: const TextStyle(
                  color: AppColors.accentDanger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          FilledButton(
            onPressed: _vm.busy ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentGold,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _vm.busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Change password',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
          ),
        ],
      ),
    );
  }
}
