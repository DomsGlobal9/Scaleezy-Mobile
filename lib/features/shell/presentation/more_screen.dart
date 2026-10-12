import 'package:flutter/material.dart';

import 'package:scaleezy/app/app_routes.dart';
import 'package:scaleezy/app/router.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/shop/shop_context.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/core/widgets/ui.dart';

class _Module {
  final IconData icon;
  final String title;
  final String blurb;
  final Color color;
  final Color bg;
  final String? permission;
  final String path;

  /// Shown only when the shop fits, beyond the permission.
  final bool Function(ShopContext shop)? onlyIf;

  const _Module(
    this.icon,
    this.title,
    this.blurb,
    this.color,
    this.bg,
    this.permission,
    this.path, {
    this.onlyIf,
  });
}

/// Everything beyond the four main tabs. A module only shows when the role can open it.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  static final _modules = <_Module>[
    _Module(
      Icons.shelves,
      'Shelves',
      'Where every piece sits',
      AppColors.accentGold,
      AppColors.accentGoldLight,
      'shelf:view',
      Paths.shelves,
    ),
    _Module(
      Icons.fact_check_rounded,
      'Stock count',
      'Check shelves against stock',
      AppColors.accentDanger,
      AppColors.accentDangerLight,
      'stock_count:view',
      Paths.stockCounts,
    ),
    _Module(
      Icons.move_to_inbox_rounded,
      'Purchase Orders',
      'Receive deliveries',
      AppColors.accentBlue,
      AppColors.accentBlueLight,
      'purchase_order:view',
      Paths.purchaseOrders,
    ),
    _Module(
      Icons.swap_horiz_rounded,
      'Move stock',
      'To another store',
      AppColors.textPrimary,
      AppColors.bgSurface,
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
      AppColors.accentPurple,
      AppColors.accentPurpleLight,
      'customer:view',
      Paths.customers,
    ),
    _Module(
      Icons.menu_book_rounded,
      'Day book',
      'One day, closed off',
      AppColors.accentDanger,
      AppColors.accentDangerLight,
      'report:financial',
      Paths.dayBook,
    ),
    _Module(
      Icons.handshake_rounded,
      'Suppliers',
      'Who you buy from',
      AppColors.accentSuccess,
      AppColors.accentSuccessLight,
      'supplier:view',
      Paths.suppliers,
    ),
    _Module(
      Icons.badge_rounded,
      'Team & Users',
      'People and their roles',
      AppColors.accentWarning,
      const Color(0xFFFFFBEB),
      'admin:users',
      Paths.team,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final shop = ShopScope.of(context);
    final user = session.user;
    final modules = _modules
        .where((m) => m.permission == null || session.can(m.permission!))
        .where((m) => m.onlyIf?.call(shop) ?? true)
        .toList();

    void open(String path) => AppRoutes.open(context, path);

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
          children: [
            const Text(
              'More',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.7,
              ),
            ).entrance(0),
            const SizedBox(height: 14),
            // Who is signed in, and where
            Pressable(
              onTap: () => open(Paths.settings),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: AppColors.heroGradient,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.goldGradient,
                        border: Border.all(color: Colors.white24, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initialsOf(user?.name ?? ''),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                                  user?.roles.firstOrNull,
                                  shop.branding.businessName ?? user?.clientId,
                                ]
                                .whereType<String>()
                                .where((s) => s.isNotEmpty)
                                .join(' • '),
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.settings_rounded,
                      color: Color(0xFFFDE68A),
                    ),
                  ],
                ),
              ),
            ).entrance(1),
            const SizedBox(height: 22),
            if (modules.isNotEmpty) ...[
              const SectionHeader(title: 'Tools').entrance(2),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
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
                              color: m.bg,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(m.icon, color: m.color, size: 22),
                          ),
                          const Spacer(),
                          Text(
                            m.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            m.blurb,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ).entrance(3 + i),
                ],
              ),
              const SizedBox(height: 22),
            ],
            const SectionHeader(title: 'Account').entrance(9),
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _row(
                    Icons.person_outline_rounded,
                    'Profile and shop details',
                    () => open(Paths.settings),
                  ),
                  const Divider(height: 1, indent: 56),
                  _row(Icons.logout_rounded, 'Sign out', () async {
                    if (await confirmAction(
                      context,
                      title: 'Sign out?',
                      message:
                          'You will need your email and password to come back in.',
                      confirmLabel: 'Sign out',
                    )) {
                      session.logout();
                    }
                  }, danger: true),
                ],
              ),
            ).entrance(10),
          ],
        ),
      ),
    );
  }

  Widget _row(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool danger = false,
  }) => ListTile(
    onTap: onTap,
    leading: Icon(
      icon,
      color: danger ? AppColors.accentDanger : AppColors.textSecondary,
    ),
    title: Text(
      label,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 14,
        color: danger ? AppColors.accentDanger : AppColors.textPrimary,
      ),
    ),
    trailing: danger
        ? null
        : const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
  );
}
