import 'package:scaleezy/core/theme/app_theme.dart';

/// What a stored status reads as on screen, and its colour. Mirrors the website's
/// `components/sales/labels.jsx` and docs/design.md, keyed by the server's enum value.
typedef StatusLook = ({String label, Tone tone});

const Map<String, StatusLook> orderStatuses = {
  'DRAFT': (label: 'Draft', tone: Tone.neutral),
  'CONFIRMED': (label: 'Confirmed', tone: Tone.info),
  'PARTIALLY_DISPATCHED': (label: 'Partly sent', tone: Tone.warning),
  'DISPATCHED': (label: 'Dispatched', tone: Tone.success),
  'CANCELLED': (label: 'Cancelled', tone: Tone.danger),
};

/// Part paid and unpaid orders show "₹X due" in [Tone.warning] where the amount is known.
const Map<String, StatusLook> paymentStatuses = {
  'PAID': (label: 'Paid', tone: Tone.success),
  'PART_PAID': (label: 'Part paid', tone: Tone.warning),
  'UNPAID': (label: 'Unpaid', tone: Tone.warning),
  'REFUNDED': (label: 'Refunded', tone: Tone.neutral),
  'WRITTEN_OFF': (label: 'Written off', tone: Tone.danger),
};

const Map<String, StatusLook> returnStatuses = {
  'REQUESTED': (label: 'Requested', tone: Tone.warning),
  'RECEIVED': (label: 'Received', tone: Tone.info),
  'INSPECTED': (label: 'Inspected', tone: Tone.purple),
  'COMPLETED': (label: 'Completed', tone: Tone.success),
  'REJECTED': (label: 'Turned down', tone: Tone.danger),
};

const Map<String, StatusLook> purchaseOrderStatuses = {
  'DRAFT': (label: 'Draft', tone: Tone.neutral),
  'SENT': (label: 'Sent', tone: Tone.info),
  'PARTIALLY_RECEIVED': (label: 'Partly received', tone: Tone.gold),
  'RECEIVED': (label: 'Received', tone: Tone.success),
  'CANCELLED': (label: 'Cancelled', tone: Tone.danger),
};

const Map<String, StatusLook> stockCountStatuses = {
  'DRAFT': (label: 'Draft', tone: Tone.neutral),
  'IN_PROGRESS': (label: 'In progress', tone: Tone.gold),
  'COMPLETED': (label: 'Completed', tone: Tone.success),
  'CANCELLED': (label: 'Cancelled', tone: Tone.danger),
};

const Map<String, StatusLook> stockStates = {
  'HEALTHY': (label: 'Healthy', tone: Tone.success),
  'LOW_STOCK': (label: 'Low stock', tone: Tone.warning),
  'OUT_OF_STOCK': (label: 'Out of stock', tone: Tone.danger),
};

/// Active is the only coloured product status; the rest are neutral.
const Map<String, StatusLook> productStatuses = {
  'ACTIVE': (label: 'Active', tone: Tone.success),
  'DRAFT': (label: 'Draft', tone: Tone.neutral),
  'ARCHIVED': (label: 'Archived', tone: Tone.neutral),
  'TRASHED': (label: 'In trash', tone: Tone.neutral),
  'OUT_OF_STOCK': (label: 'Out of stock', tone: Tone.neutral),
};

/// [value]'s look in [map], or a readable neutral stand-in for a status added on the server later:
/// "SOME_NEW_STATE" reads "Some new state".
StatusLook describeStatus(Map<String, StatusLook> map, String? value) {
  final known = map[value];
  if (known != null) return known;
  final text = (value ?? '').replaceAll('_', ' ').trim().toLowerCase();
  return (
    label: text.isEmpty ? '—' : text[0].toUpperCase() + text.substring(1),
    tone: Tone.neutral,
  );
}
