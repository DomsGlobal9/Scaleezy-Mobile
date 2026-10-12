import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scaleezy/app/app.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/shop/shop_context.dart';
import 'package:scaleezy/core/theme/app_theme.dart';

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
