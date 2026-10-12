import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/core/theme/status_tones.dart';

void main() {
  // Every status docs/design.md lists, with the label and tone the website shows.
  void expectLooks(Map<String, StatusLook> map, Map<String, StatusLook> spec) {
    expect(map.keys, containsAll(spec.keys));
    spec.forEach((value, look) => expect(map[value], look, reason: value));
  }

  test('orders', () {
    expectLooks(orderStatuses, {
      'DRAFT': (label: 'Draft', tone: Tone.neutral),
      'CONFIRMED': (label: 'Confirmed', tone: Tone.info),
      'PARTIALLY_DISPATCHED': (label: 'Partly sent', tone: Tone.warning),
      'DISPATCHED': (label: 'Dispatched', tone: Tone.success),
      'CANCELLED': (label: 'Cancelled', tone: Tone.danger),
    });
  });

  test('payment', () {
    expectLooks(paymentStatuses, {
      'PAID': (label: 'Paid', tone: Tone.success),
      'REFUNDED': (label: 'Refunded', tone: Tone.neutral),
      'WRITTEN_OFF': (label: 'Written off', tone: Tone.danger),
    });
    expect(paymentStatuses['PART_PAID']!.tone, Tone.warning);
    expect(paymentStatuses['UNPAID']!.tone, Tone.warning);
  });

  test('returns', () {
    expectLooks(returnStatuses, {
      'REQUESTED': (label: 'Requested', tone: Tone.warning),
      'RECEIVED': (label: 'Received', tone: Tone.info),
      'INSPECTED': (label: 'Inspected', tone: Tone.purple),
      'COMPLETED': (label: 'Completed', tone: Tone.success),
      'REJECTED': (label: 'Turned down', tone: Tone.danger),
    });
  });

  test('purchase orders', () {
    expectLooks(purchaseOrderStatuses, {
      'DRAFT': (label: 'Draft', tone: Tone.neutral),
      'SENT': (label: 'Sent', tone: Tone.info),
      'PARTIALLY_RECEIVED': (label: 'Partly received', tone: Tone.gold),
      'RECEIVED': (label: 'Received', tone: Tone.success),
      'CANCELLED': (label: 'Cancelled', tone: Tone.danger),
    });
  });

  test('stock counts', () {
    expectLooks(stockCountStatuses, {
      'DRAFT': (label: 'Draft', tone: Tone.neutral),
      'IN_PROGRESS': (label: 'In progress', tone: Tone.gold),
      'COMPLETED': (label: 'Completed', tone: Tone.success),
      'CANCELLED': (label: 'Cancelled', tone: Tone.danger),
    });
  });

  test('stock state and product status', () {
    expect(stockStates['HEALTHY']!.tone, Tone.success);
    expect(stockStates['LOW_STOCK']!.tone, Tone.warning);
    expect(stockStates['OUT_OF_STOCK']!.tone, Tone.danger);
    expect(productStatuses['ACTIVE'], (label: 'Active', tone: Tone.success));
    for (final s in ['DRAFT', 'ARCHIVED', 'TRASHED', 'OUT_OF_STOCK']) {
      expect(productStatuses[s]!.tone, Tone.neutral, reason: s);
    }
  });

  test('an unknown status reads as sentence case, neutral', () {
    expect(describeStatus(orderStatuses, 'CONFIRMED').label, 'Confirmed');
    expect(describeStatus(orderStatuses, 'SOME_NEW_STATE'), (
      label: 'Some new state',
      tone: Tone.neutral,
    ));
    expect(describeStatus(orderStatuses, null).label, '—');
  });
}
