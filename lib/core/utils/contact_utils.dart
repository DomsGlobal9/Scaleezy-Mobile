import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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
