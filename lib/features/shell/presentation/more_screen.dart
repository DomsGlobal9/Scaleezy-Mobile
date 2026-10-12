import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:scaleezy/app/app_routes.dart';
import 'package:scaleezy/app/router.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/shop/shop_context.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/core/theme/theme_mode_store.dart';
import 'package:scaleezy/core/utils/labels.dart';
import 'package:scaleezy/core/widgets/ui.dart';

class _Module {
  final IconData icon;
  final String title;
  final String blurb;
  final Tone tone;
  final String? permission;
  final String path;

  /// Shown only when the shop fits, beyond the permission.
  final bool Function(ShopContext shop)? onlyIf;

  const _Module(
    this.icon,
    this.title,
    this.blurb,
    this.tone,
    this.permission,
    this.path, {
    this.onlyIf,
  });
}

/// Everything beyond the four main tabs, laid out like the website's settings hub: who is
/// signed in and in which shop, the tools the role can open, appearance and the account.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  static final _modules = <_Module>[
    _Module(
      Icons.shelves,
      'Shelves',
      'Where every piece sits',
      Tone.success,
      'shelf:view',
      Paths.shelves,
    ),
    _Module(
      Icons.fact_check_rounded,
      'Stock count',
      'Check shelves against stock',
      Tone.gold,
      'stock_count:view',
      Paths.stockCounts,
    ),
    _Module(
      Icons.move_to_inbox_rounded,
      'Purchase Orders',
      'Receive deliveries',
      Tone.info,
      'purchase_order:view',
      Paths.purchaseOrders,
    ),
    _Module(
      Icons.swap_horiz_rounded,
      'Move stock',
      'To another store',
      Tone.neutral,
      'inventory:transfer',
      Paths.transfers,
      // Moving needs two real stores; the online shop does not count.
      onlyIf: (shop) =>
          shop.locations.where((l) => l.type != 'ONLINE').length >= 2,
    ),
    _Module(
      Icons.people_alt_rounded,
      'Customers',
      'Look up, add, call',
      Tone.purple,
      'customer:view',
      Paths.customers,
    ),
    _Module(
      Icons.menu_book_rounded,
      'Day book',
      'One day, closed off',
      Tone.danger,
      'report:financial',
      Paths.dayBook,
    ),
    _Module(
      Icons.handshake_rounded,
      'Suppliers',
      'Who you buy from',
      Tone.success,
      'supplier:view',
      Paths.suppliers,
    ),
    _Module(
      Icons.badge_rounded,
      'Team & Users',
      'People and their roles',
      Tone.warning,
      'admin:users',
      Paths.team,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final shop = ShopScope.of(context);
    final c = context.colors;
    final type = Theme.of(context).textTheme;
    final modules = _modules
        .where((m) => m.permission == null || session.can(m.permission!))
        .where((m) => m.onlyIf?.call(shop) ?? true)
        .toList();

    void open(String path) => AppRoutes.open(context, path);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          children: [
            Text('More', style: type.headlineSmall).entrance(0),
            const SizedBox(height: 14),
            _Profile(onTap: () => open(Paths.settings)).entrance(1),
            const SizedBox(height: 22),
            if (modules.isNotEmpty) ...[
              const SectionHeader(title: 'Tools').entrance(2),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.25,
                children: [
                  for (final (i, m) in modules.indexed)
                    SurfaceCard(
                      onTap: () => open(m.path),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: tint(c.tone(m.tone)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              m.icon,
                              color: c.tone(m.tone),
                              size: 22,
                            ),
                          ),
                          const Spacer(),
                          Text(m.title, style: type.titleSmall),
                          const SizedBox(height: 2),
                          Text(
                            m.blurb,
                            style: type.labelMedium!.copyWith(
                              color: c.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ).entrance(3 + i),
                ],
              ),
              const SizedBox(height: 22),
            ],
            if (ThemeModeScope.maybeOf(context) case final store?) ...[
              const SectionHeader(title: 'Appearance').entrance(9),
              _Appearance(store).entrance(9),
              const SizedBox(height: 22),
            ],
            const SectionHeader(title: 'Account').entrance(10),
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _row(
                    context,
                    Icons.person_outline_rounded,
                    'Profile and shop details',
                    () => open(Paths.settings),
                  ),
                  const Divider(height: 1, indent: 56),
                  // No confirmation, as everywhere else (and on the website).
                  _row(
                    context,
                    Icons.logout_rounded,
                    'Sign out',
                    session.logout,
                    danger: true,
                  ),
                ],
              ),
            ).entrance(11),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool danger = false,
  }) {
    final c = context.colors;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: danger ? c.danger : c.textSecondary),
      title: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.titleSmall!.copyWith(color: danger ? c.danger : c.text),
      ),
      trailing: danger
          ? null
          : Icon(Icons.chevron_right_rounded, color: c.textMuted),
    );
  }
}

/// The website's settings-hub profile block: the shop's logo (or the person's initials) on a
/// white tile, name, role and shop, on the brand colour at 16%.
class _Profile extends StatelessWidget {
  final VoidCallback onTap;
  const _Profile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final user = SessionScope.of(context).user;
    final branding = ShopScope.of(context).branding;
    final c = context.colors;
    final type = Theme.of(context).textTheme;
    final initials = Center(
      child: Text(
        initialsOf(user?.name ?? ''),
        style: type.titleLarge!.copyWith(
          color: AppPalette.light.brandInk,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Color.alphaBlend(tint(c.brand, 0.16), c.card),
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              clipBehavior: Clip.antiAlias,
              // White in both themes so any logo reads.
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: branding.logoUrl == null
                  ? initials
                  : Padding(
                      padding: const EdgeInsets.all(5),
                      child: CachedNetworkImage(
                        imageUrl: branding.logoUrl!,
                        fit: BoxFit.contain,
                        errorWidget: (_, _, _) => initials,
                      ),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.name ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: type.titleMedium!.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    roleLabel(user),
                    style: type.labelMedium!.copyWith(color: c.textSecondary),
                  ),
                  if ((branding.businessName ?? user?.clientId) != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      branding.businessName ?? user!.clientId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.titleSmall,
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.textMuted),
          ],
        ),
      ),
    );
  }
}

/// System / Light / Dark, applied at once and remembered.
class _Appearance extends StatelessWidget {
  final ThemeModeStore store;
  const _Appearance(this.store);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<ThemeMode>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: ThemeMode.system,
            label: Text('System'),
            icon: Icon(Icons.brightness_auto_rounded, size: 18),
          ),
          ButtonSegment(
            value: ThemeMode.light,
            label: Text('Light'),
            icon: Icon(Icons.light_mode_rounded, size: 18),
          ),
          ButtonSegment(
            value: ThemeMode.dark,
            label: Text('Dark'),
            icon: Icon(Icons.dark_mode_rounded, size: 18),
          ),
        ],
        selected: {store.value},
        onSelectionChanged: (picked) => store.save(picked.single),
      ),
    );
  }
}
