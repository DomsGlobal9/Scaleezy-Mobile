import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/core/widgets/async_state.dart';

Future<void> launchContact(BuildContext context, Uri uri) async {
  final ok = await launchUrl(uri);
  if (!ok && context.mounted) {
    showMessage(context, 'No app on this phone can open that.', error: true);
  }
}

/// wa.me wants the country code; Indian numbers are often stored as 10 digits.
String whatsappNumber(String phone) {
  final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.length == 10 ? '91$digits' : digits;
}

/// A soft colour per person, so a long list is easy to scan.
Color avatarColour(String seed) {
  const palette = [
    AppColors.accentGold,
    AppColors.accentBlue,
    AppColors.accentPurple,
    AppColors.accentSuccess,
    AppColors.accentDanger,
  ];
  return palette[seed.codeUnits.fold<int>(0, (a, c) => a + c) % palette.length];
}
