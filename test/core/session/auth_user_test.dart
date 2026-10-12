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

  test('a legacy SUPER_ADMIN role is the owner, as on the backend', () {
    final legacy = AuthUser.fromJson({
      'id': 'u',
      'email': 'a@b.c',
      'roles': ['SUPER_ADMIN'],
      'permissions': ['dashboard:view'],
    });
    expect(legacy.isOwner, isTrue);
    expect(legacy.can('cost:view'), isTrue);
  });
}
