/// One way to write a phone number, ported from the website's `utils/phone.js` (the same rule as
/// the server's `lib/phone.ts`), so the form says what is wrong before Save. The server still
/// decides.
///
/// Indian mobiles: 10 digits starting 6-9, with or without +91 / 91 / a leading 0, stored as
/// "+919848022338". Another country: + (or 00) and the country code, 8-15 digits.
library;

const _indiaHint =
    'Enter a 10-digit mobile number, or + and the country code for a number from another country.';

bool _looksFake(String national) {
  if (RegExp(r'^(\d)\1+$').hasMatch(national)) return true;
  const ascending = '01234567890123456789';
  const descending = '98765432109876543210';
  return national.length >= 8 &&
      (ascending.contains(national) || descending.contains(national));
}

/// The stored form ("+919848022338") as `value`, or why not as `reason`.
({String? value, String? reason}) normalisePhone(String? raw) {
  ({String? value, String? reason}) no(String reason) =>
      (value: null, reason: reason);
  final typed = (raw ?? '').trim();
  if (typed.isEmpty) return no("Enter the customer's phone number.");

  final compact = typed.replaceAll(RegExp(r'[\s\-.()]'), '');
  if (!RegExp(r'^(\+|00)?\d+$').hasMatch(compact)) {
    return no('A phone number can only have digits, spaces, + and -.');
  }

  final international = compact.startsWith('+') || compact.startsWith('00');
  final digits = compact.replaceFirst(RegExp(r'^\+|^00'), '');

  if (!international || digits.startsWith('91')) {
    String? national;
    if (!international && digits.length == 10) {
      national = digits;
    } else if (!international &&
        digits.length == 11 &&
        digits.startsWith('0')) {
      national = digits.substring(1);
    } else if (digits.length == 12 && digits.startsWith('91')) {
      national = digits.substring(2);
    }
    if (national == null) {
      return no(
        international
            ? 'An Indian number has 10 digits after +91.'
            : _indiaHint,
      );
    }
    if (!RegExp(r'^[6-9]').hasMatch(national)) {
      return no('An Indian mobile number starts with 6, 7, 8 or 9.');
    }
    if (_looksFake(national)) {
      return no("That doesn't look like a real number.");
    }
    return (value: '+91$national', reason: null);
  }

  if (digits.length < 8 || digits.length > 15 || digits.startsWith('0')) {
    return no(
      'A number from another country is + then the country code and number, 8 to 15 digits.',
    );
  }
  final last10 = digits.length > 10
      ? digits.substring(digits.length - 10)
      : digits;
  if (_looksFake(last10)) return no("That doesn't look like a real number.");
  return (value: '+$digits', reason: null);
}

// Zero of the Devanagari, Tamil, Telugu and Kannada digits a phone keyboard may type.
const _localDigitZeros = [0x0966, 0x0be6, 0x0c66, 0x0ce6];

/// What a phone box keeps as it is typed or pasted: digits, spaces and + - ( ) . only, a + only
/// at the start, and no more digits than a number can have (12 for an Indian number, 15 with +
/// or 00). Local-script digits become 0-9.
String typedPhone(String raw) {
  final ascii = String.fromCharCodes(
    raw.runes.map((r) {
      for (final zero in _localDigitZeros) {
        if (r >= zero && r <= zero + 9) return 0x30 + r - zero;
      }
      return r;
    }),
  );
  final kept = ascii.replaceAll(RegExp(r'[^\d +\-.()]'), '');
  final indian = RegExp(r'^\s*(\+\s*91|0091)').hasMatch(kept);
  final international = RegExp(r'^\s*(\+|00)').hasMatch(kept);
  // A leading 00 is dialling, not part of the number, so it does not use up the allowance.
  final most =
      (RegExp(r'^\s*00').hasMatch(kept) ? 2 : 0) +
      (international && !indian ? 15 : 12);
  final out = StringBuffer();
  var digits = 0;
  for (final ch in kept.split('')) {
    if (digits == most) break;
    if (ch == '+') {
      if (out.toString().trim().isEmpty) out.write(ch);
      continue;
    }
    if (RegExp(r'\d').hasMatch(ch)) digits++;
    out.write(ch);
  }
  final s = out
      .toString()
      .replaceAll(RegExp(r' {2,}'), ' ')
      .replaceFirst(RegExp(r'^ +'), '');
  return s.length > 20 ? s.substring(0, 20) : s;
}

/// "+919848022338" → "+91 98480 22338"; other countries and anything unrecognised as stored.
String formatPhone(String? stored) {
  if (stored == null || stored.isEmpty) return '';
  final m = RegExp(r'^\+91(\d{5})(\d{5})$').firstMatch(stored);
  return m == null ? stored : '+91 ${m[1]} ${m[2]}';
}

final _emailShape = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

/// Null when the email is empty or looks right; otherwise what to say under the box (the
/// website's `CustomerModal` check).
String? emailProblem(String? value) {
  final email = (value ?? '').trim();
  if (email.isEmpty) return null;
  if (email.length > 254) {
    return 'That email address is too long. Check it, or leave the box empty.';
  }
  return _emailShape.hasMatch(email)
      ? null
      : "That email address doesn't look right. Check it, or leave the box empty.";
}
