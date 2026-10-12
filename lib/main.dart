import 'package:flutter/material.dart';
import 'package:scaleezy/app/app.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/shop/shop_context.dart';
import 'package:scaleezy/core/theme/theme_mode_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final api = await ApiClient.init();
  final session = AuthSession(api);
  final shop = ShopContext(api);
  final themeMode = ThemeModeStore();
  // Before the first frame and the first request: the right colours, and the saved store
  // already on `x-location-id`.
  await Future.wait([themeMode.load(), shop.restoreSavedStore()]);

  shop.follow(session);
  session.restore();

  runApp(ScaleezyApp(session: session, shop: shop, themeMode: themeMode));
}
