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
    final c = context.colors;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: c.card,
          border: Border(top: BorderSide(color: c.border)),
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
                _scanItem(context),
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

  TextStyle _label(BuildContext context, bool selected) {
    final c = context.colors;
    return Theme.of(context).textTheme.labelMedium!.copyWith(
      fontSize: 11,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      color: selected ? c.text : c.textSecondary,
    );
  }

  /// The one brand-coloured control in the bar: a brand-solid circle.
  Widget _scanItem(BuildContext context) {
    final c = context.colors;
    final selected = _currentIndex == _scanIndex;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabSelected(_scanIndex),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: selected ? 1.06 : 1,
              duration: const Duration(milliseconds: 200),
              curve: const Cubic(.16, 1, .3, 1),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: c.brandSolid,
                  shape: BoxShape.circle,
                  boxShadow: c.panelShadow,
                ),
                child: Icon(
                  Icons.qr_code_scanner_rounded,
                  color: c.onBrandSolid,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text('Scan', style: _label(context, selected)),
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
    final c = context.colors;
    final selected = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabSelected(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Active is neutral, as the website's sidebar: text colour on the input colour.
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: const Cubic(.16, 1, .3, 1),
              padding: EdgeInsets.symmetric(
                horizontal: selected ? 18 : 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: selected ? c.input : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                selected ? selectedIcon : icon,
                color: selected ? c.text : c.textSecondary,
                size: 22,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _label(context, selected),
            ),
          ],
        ),
      ),
    );
  }
}
