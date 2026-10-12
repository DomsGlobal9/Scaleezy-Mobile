import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/session/auth_user.dart';

void main() {
  test('permissions: owner wildcard and explicit grants', () {
    final owner = AuthUser.fromJson({
      'id': 'u',
      'email': 'a@b.c',
      'roles': ['Owner'],
      'permissions': ['*'],
    });
    final clerk = AuthUser.fromJson({
      'id': 'u',
      'email': 'a@b.c',
      'roles': [],
      'permissions': ['sales_order:view'],
    }, clientId: 'sphl');
    expect(owner.can('sales_order:create'), isTrue);
    expect(clerk.can('sales_order:view'), isTrue);
    expect(clerk.can('sales_order:create'), isFalse);
    expect(clerk.clientId, 'sphl');
  });
}
