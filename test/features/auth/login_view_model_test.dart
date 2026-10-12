import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/features/auth/presentation/view_models/login_view_model.dart';

import 'auth_fakes.dart';

void main() {
  test('a sign-in is submitting until the server answers', () async {
    final reply = Completer<void>();
    final session = FakeAuthSession(answer: (_) => reply.future);
    final vm = LoginViewModel(session);

    final done = vm.submit('asha@shop.in', 'secret');
    expect(vm.submitting, isTrue);
    reply.complete();

    expect(await done, isNull);
    expect(vm.submitting, isFalse);
    expect(vm.error, isNull);
    expect(session.logins.single, ('asha@shop.in', 'secret', null));
  });

  test('the server message is returned and kept', () async {
    final vm = LoginViewModel(
      FakeAuthSession(
        answer: (_) async => throw const ApiException('Wrong password.'),
      ),
    );

    expect(await vm.submit('asha@shop.in', 'nope'), 'Wrong password.');
    expect(vm.error, 'Wrong password.');
    expect(vm.submitting, isFalse);
  });

  test('a workspace choice is offered, then sent with the next try', () async {
    final session = FakeAuthSession(
      answer: (clientId) async {
        if (clientId == null) {
          throw const WorkspaceChoiceRequired('Choose a shop.', ['a', 'b']);
        }
      },
    );
    final vm = LoginViewModel(session);

    expect(await vm.submit('asha@shop.in', 'secret'), isNull);
    expect(vm.workspaceChoice?.message, 'Choose a shop.');
    expect(vm.workspaceChoice?.clientIds, ['a', 'b']);
    expect(vm.error, isNull);

    await vm.submit('asha@shop.in', 'secret', clientId: 'b');
    expect(session.logins.last, ('asha@shop.in', 'secret', 'b'));
    expect(vm.workspaceChoice, isNull);
  });
}
