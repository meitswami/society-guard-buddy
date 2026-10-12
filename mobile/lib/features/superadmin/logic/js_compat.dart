/// Small helpers that reproduce the JavaScript semantics the web Superadmin
/// dashboard relies on (`parseInt`, `Number(...)`, regex checks), so the mobile
/// port saves exactly the same values.
library;

/// JS `parseInt(value, 10)`: skips leading whitespace, optional sign, then reads
/// digits until the first non-digit. Returns `null` where JS would return `NaN`.
int? jsParseInt(String? value) {
  if (value == null) return null;
  final m = RegExp(r'^\s*([+-]?\d+)').firstMatch(value);
  if (m == null) return null;
  return int.tryParse(m.group(1)!);
}

/// JS `Number(value)` for strings: trims, empty → 0, decimal / exponent / hex,
/// anything else → `NaN`.
double jsNumber(String? value) {
  final s = (value ?? '').trim();
  if (s.isEmpty) return 0;
  final hex = RegExp(r'^0[xX][0-9a-fA-F]+$');
  if (hex.hasMatch(s)) return int.parse(s.substring(2), radix: 16).toDouble();
  if (!RegExp(r'^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$').hasMatch(s) &&
      s != 'Infinity' &&
      s != '+Infinity' &&
      s != '-Infinity') {
    return double.nan;
  }
  return double.tryParse(s.replaceFirst('+Infinity', 'Infinity')) ?? double.nan;
}

/// A JSON-friendly number: integral doubles are sent as ints (JS `JSON.stringify(40)` → `40`).
num jsonNumber(double v) => v == v.roundToDouble() && v.isFinite ? v.toInt() : v;

/// Web `/^[^\s@]+@[^\s@]+\.[^\s@]+$/` (recovery e-mail validation).
bool isValidEmail(String value) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);

/// Web `file.name.replace(/[^\w.-]/g, '_')` used in storage object paths.
String safeStorageFileName(String name) => name.replaceAll(RegExp(r'[^\w.-]'), '_');

/// Web `blocks_csv.split(/[,;]+/).map((x) => x.trim()).filter(Boolean)`.
List<String> splitBlocksCsv(String csv) =>
    csv.split(RegExp(r'[,;]+')).map((x) => x.trim()).where((x) => x.isNotEmpty).toList();

/// Keeps only digits and caps the length (web `value.replace(/\D/g, '').slice(0, 6)`).
String digitsOnly(String value, {int? maxLength}) {
  final d = value.replaceAll(RegExp(r'\D'), '');
  if (maxLength == null || d.length <= maxLength) return d;
  return d.substring(0, maxLength);
}
