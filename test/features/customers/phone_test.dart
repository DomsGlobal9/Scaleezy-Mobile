import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/features/customers/data/phone.dart';

void main() {
  group('normalisePhone (the website rule)', () {
    test('Indian numbers in every usual spelling are stored as +91…', () {
      for (final typed in [
        '9848022338',
        '98480 22338',
        '098480-22338',
        '919848022338',
        '+91 98480 22338',
        '0091 9848022338',
      ]) {
        expect(normalisePhone(typed).value, '+919848022338', reason: typed);
      }
    });

    test('other countries keep their code', () {
      expect(normalisePhone('+44 20 7946 0958').value, '+442079460958');
      expect(normalisePhone('0044 2079460958').value, '+442079460958');
    });

    test('each mistake says what is wrong', () {
      String? why(String s) => normalisePhone(s).reason;
      expect(why(''), "Enter the customer's phone number.");
      expect(
        why('98480x22338'),
        'A phone number can only have digits, spaces, + and -.',
      );
      expect(
        why('12345'),
        'Enter a 10-digit mobile number, or + and the country code for a number from another country.',
      );
      expect(why('+91 98480'), 'An Indian number has 10 digits after +91.');
      expect(
        why('5848022338'),
        'An Indian mobile number starts with 6, 7, 8 or 9.',
      );
      expect(why('9999999999'), "That doesn't look like a real number.");
      expect(why('9876543210'), "That doesn't look like a real number.");
      expect(
        why('+1 234'),
        'A number from another country is + then the country code and number, 8 to 15 digits.',
      );
    });
  });

  test('typedPhone keeps only what a number can have', () {
    expect(typedPhone('98480abc22338'), '9848022338');
    expect(typedPhone('9848+022338'), '9848022338');
    expect(typedPhone('  +91  98480 22338'), '+91 98480 22338');
    // No more digits than a number can have.
    expect(typedPhone('98480223381234'), '984802233812');
    expect(typedPhone('+4412345678901234567'), '+441234567890123');
    // Devanagari and Telugu digits become 0-9.
    expect(typedPhone('९८४८०२२३३८'), '9848022338');
    expect(typedPhone('౯౮'), '98');
  });

  test('formatPhone shows Indian numbers in two groups', () {
    expect(formatPhone('+919848022338'), '+91 98480 22338');
    expect(formatPhone('+442079460958'), '+442079460958');
    expect(formatPhone(null), '');
  });

  test('emailProblem checks the shape only when there is one', () {
    expect(emailProblem(''), isNull);
    expect(emailProblem(' asha@shop.in '), isNull);
    expect(
      emailProblem('asha@shop'),
      "That email address doesn't look right. Check it, or leave the box empty.",
    );
    expect(
      emailProblem('${'a' * 250}@b.in'),
      'That email address is too long. Check it, or leave the box empty.',
    );
  });
}
