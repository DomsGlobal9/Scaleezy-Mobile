import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api/api_client.dart';
import 'api/auth_session.dart';
import 'api/shop_context.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style for clean light boutique aesthetic
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.bgCard,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  final api = await ApiClient.init();
  final session = AuthSession(api);
  final shop = ShopContext(api);
  // Branding and stores follow whoever is signed in.
  session.addListener(() {
    if (session.status == AuthStatus.signedIn) {
      shop.load();
    } else if (session.status == AuthStatus.signedOut) {
      shop.clear();
    }
  });
  session.restore();

  runApp(ScaleezyApp(session: session, shop: shop));
}

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
