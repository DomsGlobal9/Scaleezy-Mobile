import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/session/auth_user.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/core/utils/labels.dart';

AuthUser user(List<String> roles, {Set<String> permissions = const {}}) =>
    AuthUser(
      id: 'u1',
      clientId: 'c1',
      name: 'Asha',
      email: 'a@b.in',
      roles: roles,
      permissions: permissions,
    );

void main() {
  test('statuses read as the website words them', () {
    expect(describe(orderStatuses, 'PARTIALLY_DISPATCHED'), 'Partly sent');
    expect(describe(returnStatuses, 'REJECTED'), 'Turned down');
    expect(describe(dispatchStatuses, 'SHIPPED'), 'Sent');
    expect(describe(dispatchStatuses, 'PICKING'), 'Being picked');
    expect(describe(customerStatuses, 'INACTIVE'), 'Inactive');
    expect(describe(returnDispositions, 'PENDING'), 'Not inspected yet');
    expect(describeStatus(customerStatuses, 'ARCHIVED').tone, Tone.danger);
  });

  test('a status nobody has heard of still reads as words', () {
    expect(describe(orderStatuses, 'ON_HOLD_FOR_REVIEW'), 'On hold for review');
    expect(describe(orderStatuses, null), '—');
    expect(returnReasonLabel('SIZE_ISSUE'), 'Size did not fit');
    expect(returnReasonLabel('NEW_REASON'), 'New reason');
  });

  test('roles: Owner for the owner, else Title Case', () {
    expect(roleLabel(user(['STORE_MANAGER'], permissions: {'*'})), 'Owner');
    expect(roleLabel(user(['SUPER_ADMIN'])), 'Owner');
    expect(
      roleLabel(user(['STORE_MANAGER', 'sales staff'])),
      'Store Manager, Sales Staff',
    );
    expect(roleLabel(user([])), 'Team member');
    expect(roleLabel(null), '');
    expect(roleName('INVENTORY_CLERK'), 'Inventory Clerk');
  });
}
