import 'package:flutter/material.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/shop/shop_context.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/features/auth/presentation/login_screen.dart';
import 'package:scaleezy/features/shell/presentation/main_navigation_screen.dart';

class ScaleezyApp extends StatelessWidget {
  final AuthSession session;
  final ShopContext shop;

  const ScaleezyApp({super.key, required this.session, required this.shop});

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      session: session,
      child: ShopScope(
        shop: shop,
        child: MaterialApp(
          title: 'ScaleEzy Inventory',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          themeMode: ThemeMode.light,
          home: const AuthGate(),
        ),
      ),
    );
  }
}

/// Sign-in or the app, following the session. A 401 anywhere lands back here.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final status = SessionScope.of(context).status;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOutCubic,
      child: switch (status) {
        AuthStatus.unknown => const Scaffold(
          key: ValueKey('splash'),
          backgroundColor: AppColors.bgLight,
          body: Center(
            child: CircularProgressIndicator(color: AppColors.accentGold),
          ),
        ),
        AuthStatus.signedOut => const LoginScreen(key: ValueKey('login')),
        AuthStatus.signedIn => const MainNavigationScreen(key: ValueKey('app')),
      },
    );
  }
}
