// Shapes read from inventory_backend (main). Prisma Decimal fields serialise as strings
// ("2123.50"), plain numbers as numbers, so money is parsed from either.

double? asMoney(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

int asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

String asString(dynamic v) => v is String ? v : (v?.toString() ?? '');

String? asOptString(dynamic v) => v is String && v.trim().isNotEmpty ? v : null;

/// Missing or unreadable dates become "now".
DateTime asDateOrNow(dynamic v) =>
    (v is String ? DateTime.tryParse(v)?.toLocal() : null) ?? DateTime.now();

DateTime? asDate(dynamic v) =>
    v is String ? DateTime.tryParse(v)?.toLocal() : null;

Map<String, dynamic> asMap(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : const {};

List<Map<String, dynamic>> asMaps(dynamic v) => v is List
    ? v.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
    : const [];

/// "#B91C1C" / "B91C1C" -> 0xFFB91C1C.
int? asHexColor(dynamic v) {
  final s = asOptString(v)?.replaceFirst('#', '');
  if (s == null || s.length != 6) return null;
  final n = int.tryParse(s, radix: 16);
  return n == null ? null : 0xFF000000 | n;
}
