/// The words a shop reads for stored states, reasons and roles, as the website's
/// `components/sales/labels.jsx`. The status maps (with their colours) live in
/// `status_tones.dart` and are re-exported here, so a word is only ever written once.
library;

import 'package:scaleezy/core/session/auth_user.dart';
import 'package:scaleezy/core/theme/status_tones.dart';

export 'package:scaleezy/core/theme/status_tones.dart';

/// [value]'s label in [map]; a status the app has not heard of reads "Some new state", not
/// "SOME_NEW_STATE". Same as the website's `describe(map, value).label`.
String describe(Map<String, StatusLook> map, String? value) =>
    describeStatus(map, value).label;

/// Return reasons in the order the website's return form offers them; the key is what the
/// server stores.
const Map<String, String> returnReasons = {
  'DAMAGED_IN_TRANSIT': 'Damaged on the way to the customer',
  'DEFECTIVE': 'Faulty or badly made',
  'WRONG_ITEM': 'We sent the wrong thing',
  'SIZE_ISSUE': 'Size did not fit',
  'CUSTOMER_REJECTED': 'Customer changed their mind',
  'OTHER': 'Something else',
};

String returnReasonLabel(String? value) =>
    returnReasons[value] ?? describeStatus(const {}, value).label;

/// "Owner" for the account owner, else each role in Title Case ("STORE_MANAGER" reads
/// "Store Manager"), as the website's settings hub.
String roleLabel(AuthUser? user) {
  if (user == null) return '';
  if (user.isOwner) return 'Owner';
  if (user.roles.isEmpty) return 'Team member';
  return user.roles.map(roleName).join(', ');
}

/// One role name as people read it: "STORE_MANAGER" → "Store Manager" (e.g. team lists).
String roleName(String role) => role
    .toLowerCase()
    .split(RegExp(r'[_\s]+'))
    .where((w) => w.isNotEmpty)
    .map((w) => w[0].toUpperCase() + w.substring(1))
    .join(' ');
