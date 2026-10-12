import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:scaleezy/core/theme/app_theme.dart';

/// The bottom bar around the five tabs. Each tab is a go_router branch with its own back stack
/// (see lib/app/router.dart).
class MainNavigationScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainNavigationScreen({super.key, required this.navigationShell});

  static const _scanIndex = 2;

  /// Switches to tab [index] from inside any tab, as tapping it would.
  static void selectTab(BuildContext context, int index) =>
      _select(StatefulNavigationShell.of(context).widget, index);

  /// Tapping the tab already showing takes it back to its first screen.
  static void _select(StatefulNavigationShell shell, int index) {
    if (index != shell.currentIndex) HapticFeedback.selectionClick();
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }

  int get _currentIndex => navigationShell.currentIndex;

  void _onTabSelected(int index) => _select(navigationShell, index);

  @override
  Widget build(BuildContext context) {
    // Back on another tab's first screen goes to Dashboard; on Dashboard it leaves the app.
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) navigationShell.goBranch(0);
      },
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          border: const Border(top: BorderSide(color: AppColors.borderLight)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
            child: Row(
              children: [
                _navItem(
                  context,
                  0,
                  Icons.space_dashboard_outlined,
                  Icons.space_dashboard_rounded,
                  'Dashboard',
                ),
                _navItem(
                  context,
                  1,
                  Icons.checkroom_outlined,
                  Icons.checkroom_rounded,
                  'Products',
                ),
                _scanItem(),
                _navItem(
                  context,
                  3,
                  Icons.receipt_long_outlined,
                  Icons.receipt_long_rounded,
                  'Orders',
                ),
                _navItem(
                  context,
                  4,
                  Icons.grid_view_outlined,
                  Icons.grid_view_rounded,
                  'More',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _scanItem() {
    final selected = _currentIndex == _scanIndex;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabSelected(_scanIndex),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: selected ? 1.08 : 1,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: AppColors.goldGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentGold.withValues(
                        alpha: selected ? 0.5 : 0.3,
                      ),
                      blurRadius: selected ? 18 : 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Scan',
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected
                    ? AppColors.accentGold
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(
    BuildContext context,
    int index,
    IconData icon,
    IconData selectedIcon,
    String label,
  ) {
    final selected = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabSelected(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                horizontal: selected ? 18 : 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.accentGold.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (c, a) =>
                    ScaleTransition(scale: a, child: c),
                child: Icon(
                  selected ? selectedIcon : icon,
                  key: ValueKey(selected),
                  color: selected
                      ? AppColors.accentGold
                      : AppColors.textSecondary,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected
                    ? AppColors.accentGold
                    : AppColors.textSecondary,
                fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
              ),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
