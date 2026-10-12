import 'package:intl/intl.dart';

final _whole = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);
final _paise = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 2,
);

/// ₹2,123 or ₹2,123.50 -- paise are shown when there are any, never rounded away.
String formatRupees(num value) {
  final hasPaise = (value * 100).round() % 100 != 0;
  return (hasPaise ? _paise : _whole).format(value);
}
