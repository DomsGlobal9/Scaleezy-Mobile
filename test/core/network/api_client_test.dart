import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/network/api_client.dart';

import '../../support/fake_api.dart';

/// The error a GET /x answered with [answer] becomes.
Future<ApiException> errorOf(Object answer) async {
  final api = FakeApi()..get('/x', answer);
  try {
    await api.client.get('/x');
  } on ApiException catch (e) {
    return e;
  }
  fail('expected an ApiException');
}

void main() {
  test(
    'a validation answer lists what is wrong, as the website does',
    () async {
      final e = await errorOf(
        validationFailed(
          ['Phone must be 10 digits', 'Name is required'],
          paths: ['phone', 'name'],
        ),
      );
      expect(e.message, 'Phone must be 10 digits; Name is required');
      expect(e.statusCode, 400);
    },
  );

  test('an empty errors list falls back to the message', () async {
    final e = await errorOf(
      const FakeAnswer(409, {'message': 'Already taken.', 'errors': []}),
    );
    expect(e.message, 'Already taken.');
  });

  test('the whole error body is kept for fields beyond the message', () async {
    final e = await errorOf(
      conflict(
        'Priya Sharma (CUS-000041) is already saved with that number.',
        fields: {
          'existingCustomerId': 'c41',
          'existingCustomerName': 'Priya Sharma',
        },
      ),
    );
    expect(e.body!['existingCustomerId'], 'c41');
    expect(e.body!['existingCustomerName'], 'Priya Sharma');

    final unsuccessful = await errorOf(
      ok(null)..addAll({'success': false, 'message': 'Not allowed here.'}),
    );
    expect(unsuccessful.message, 'Not allowed here.');
    expect(unsuccessful.body!['success'], isFalse);
  });

  test('connection failures read as the website words them', () async {
    expect(
      (await errorOf(timeout())).message,
      'The server took too long to respond. Check your connection and try again.',
    );
    expect(
      (await errorOf(offline())).message,
      'Could not reach the server. Check your connection and try again.',
    );
    expect(
      (await errorOf(
        const FakeAnswer.raw(502, '<html>Bad gateway</html>'),
      )).message,
      'Something went wrong at our end. Please try again.',
    );
  });
}
