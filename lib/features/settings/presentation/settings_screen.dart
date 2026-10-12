import 'package:flutter/material.dart';

import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/shop/shop_context.dart';
import 'package:scaleezy/core/shop/shop_repository.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/core/widgets/async_state.dart';
import 'package:scaleezy/core/widgets/ui.dart';
import 'package:scaleezy/features/settings/data/account_repository.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
                  save: (v) async {
                    await AccountRepository().updateMyName(v);
                    await session.restore(); // pick up the new name everywhere
                  },
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
                  try {
                    await AccountRepository().signOutOtherDevices();
                    if (context.mounted) {
                      showMessage(
                        context,
                        'Signed out of every other device.',
                        success: true,
                      );
                    }
                  } on ApiException catch (e) {
                    if (context.mounted) {
                      showMessage(context, e.message, error: true);
                    }
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
                        save: (v) async {
                          await ShopRepository().updateShopName(
                            v.isEmpty ? null : v,
                          );
                          await shop.load();
                        },
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
                        save: (v) async {
                          await ShopRepository().updateShopDetails(
                            businessPhone: v.isEmpty ? null : v,
                            businessAddress: b.businessAddress,
                          );
                          await shop.load();
                        },
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
                        save: (v) async {
                          await ShopRepository().updateShopDetails(
                            businessAddress: v.isEmpty ? null : v,
                            businessPhone: b.businessPhone,
                          );
                          await shop.load();
                        },
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
              _tile(
                context,
                Icons.cloud_outlined,
                'Server',
                Uri.parse(kApiBaseUrl).host,
              ),
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
                    await session.logout();
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
    required Future<void> Function(String) save,
    TextInputType keyboard = TextInputType.text,
    int lines = 1,
  }) async {
    final controller = TextEditingController(text: initial);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) {
        var busy = false;
        String? error;
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
                FilledButton(
                  onPressed: busy
                      ? null
                      : () async {
                          set(() {
                            busy = true;
                            error = null;
                          });
                          try {
                            await save(controller.text.trim());
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            if (context.mounted) {
                              showMessage(context, 'Saved.', success: true);
                            }
                          } on ApiException catch (e) {
                            set(() {
                              busy = false;
                              error = e.message;
                            });
                          }
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentGold,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: busy
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
              ],
            ),
          ),
        );
      },
    );
    controller.dispose();
  }
}

class _PasswordSheet extends StatefulWidget {
  const _PasswordSheet();

  @override
  State<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<_PasswordSheet> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _again = TextEditingController();
  bool _busy = false;
  bool _show = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _again.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_next.text.length < 8) {
      return setState(
        () => _error = 'The new password must be at least 8 characters.',
      );
    }
    if (_next.text != _again.text) {
      return setState(() => _error = 'The two new passwords do not match.');
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AccountRepository().changeMyPassword(_current.text, _next.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      showMessage(
        context,
        'Password changed. Other devices have been signed out.',
        success: true,
      );
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    }
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
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: AppColors.accentDanger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          FilledButton(
            onPressed: _busy ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentGold,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _busy
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
