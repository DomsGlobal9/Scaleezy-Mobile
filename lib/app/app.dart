import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:scaleezy/app/router.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/shop/shop_context.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/core/theme/theme_mode_store.dart';

class ScaleezyApp extends StatefulWidget {
  final AuthSession session;
  final ShopContext shop;

  /// System / Light / Dark, loaded before `runApp`; tests may leave it out (Light).
  final ThemeModeStore? themeMode;

  const ScaleezyApp({
    super.key,
    required this.session,
    required this.shop,
    this.themeMode,
  });

  @override
  State<ScaleezyApp> createState() => _ScaleezyAppState();
}

class _ScaleezyAppState extends State<ScaleezyApp> {
  // Follows the session: sign-in or the app. A 401 anywhere lands back on sign-in.
  late final GoRouter _router = buildRouter(widget.session);
  late final ThemeModeStore _themeMode = widget.themeMode ?? ThemeModeStore();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      session: widget.session,
      child: ShopScope(
        shop: widget.shop,
        child: ThemeModeScope(
          store: _themeMode,
          child: ValueListenableBuilder<ThemeMode>(
            valueListenable: _themeMode,
            builder: (_, mode, _) => MaterialApp.router(
              title: 'Scaleezy Inventory',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: mode,
              routerConfig: _router,
              // Most screens have no AppBar, so the status bar icons follow the theme here.
              builder: (context, child) =>
                  AnnotatedRegion<SystemUiOverlayStyle>(
                    value: Theme.of(context).brightness == Brightness.dark
                        ? SystemUiOverlayStyle.light
                        : SystemUiOverlayStyle.dark,
                    child: child!,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
