import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:scaleezy/app/router.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/shop/shop_context.dart';
import 'package:scaleezy/core/theme/app_theme.dart';

class ScaleezyApp extends StatefulWidget {
  final AuthSession session;
  final ShopContext shop;

  const ScaleezyApp({super.key, required this.session, required this.shop});

  @override
  State<ScaleezyApp> createState() => _ScaleezyAppState();
}

class _ScaleezyAppState extends State<ScaleezyApp> {
  // Follows the session: sign-in or the app. A 401 anywhere lands back on sign-in.
  late final GoRouter _router = buildRouter(widget.session);

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
        child: MaterialApp.router(
          title: 'ScaleEzy Inventory',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          themeMode: ThemeMode.light,
          routerConfig: _router,
        ),
      ),
    );
  }
}
