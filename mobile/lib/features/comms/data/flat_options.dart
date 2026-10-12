/// Port of `src/lib/flatMultiSelectOptions.ts` (numeric flat order + option labels) and the
/// search / select-all rules of `FlatMultiSelect.tsx`. Pure Dart (unit-tested).
library;

final _chunk = RegExp(r'(\d+|\D+)');

/// Numeric flat order (101, 102, … 605, 1001) — like `a.localeCompare(b, undefined, { numeric: true })`.
int compareFlatNumbers(String a, String b) {
  final ca = _chunk.allMatches(a).map((m) => m.group(0)!).toList();
  final cb = _chunk.allMatches(b).map((m) => m.group(0)!).toList();
  final n = ca.length < cb.length ? ca.length : cb.length;
  for (var i = 0; i < n; i++) {
    final x = ca[i];
    final y = cb[i];
    final xd = _isDigits(x);
    final yd = _isDigits(y);
    if (xd && yd) {
      final c = _compareNumeric(x, y);
      if (c != 0) return c;
    } else if (xd != yd) {
      // Digits sort before letters (ICU collation).
      return xd ? -1 : 1;
    } else {
      final c = x.toLowerCase().compareTo(y.toLowerCase());
      if (c != 0) return c;
    }
  }
  if (ca.length != cb.length) return ca.length - cb.length;
  return a.compareTo(b);
}

bool _isDigits(String s) =>
    s.isNotEmpty && s.codeUnits.every((c) => c >= 48 && c <= 57);

int _compareNumeric(String x, String y) {
  final a = x.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  final b = y.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  if (a.length != b.length) return a.length - b.length;
  return a.compareTo(b);
}

List<T> sortFlatsByNumber<T>(List<T> flats, String Function(T) flatNumberOf) {
  final out = List<T>.of(flats);
  out.sort((a, b) => compareFlatNumbers(flatNumberOf(a), flatNumberOf(b)));
  return out;
}

/// Option row for the flat multi-select grid (web `FlatMultiSelectOption`).
class FlatOption {
  const FlatOption({required this.id, required this.flatNumber, this.subtitle});

  final String id;
  final String flatNumber;

  /// Primary member or owner name shown under the number.
  final String? subtitle;
}

/// Web `flatOptionsWithPrimaryLabel`: sorted options; subtitle = primary member, else owner.
List<FlatOption> flatOptionsWithPrimaryLabel(
  List<Map<String, dynamic>> flats,
  Map<String, String> primaryNameByFlatId,
) {
  final sorted =
      sortFlatsByNumber(flats, (f) => f['flat_number']?.toString() ?? '');
  return [
    for (final f in sorted)
      () {
        final id = f['id']?.toString() ?? '';
        final primary = primaryNameByFlatId[id]?.trim();
        final owner = f['owner_name']?.toString().trim();
        final subtitle = (primary != null && primary.isNotEmpty)
            ? primary
            : ((owner != null && owner.isNotEmpty) ? owner : null);
        return FlatOption(
            id: id,
            flatNumber: f['flat_number']?.toString() ?? '',
            subtitle: subtitle);
      }(),
  ];
}

/// Search filter: flat number or subtitle contains the query (case-insensitive).
List<FlatOption> filterFlatOptions(List<FlatOption> flats, String query) {
  final s = query.trim().toLowerCase();
  if (s.isEmpty) return flats;
  return flats
      .where((f) =>
          f.flatNumber.toLowerCase().contains(s) ||
          (f.subtitle?.toLowerCase().contains(s) ?? false))
      .toList();
}

/// Toggle one flat (web `toggle`).
List<String> toggleFlat(List<String> selected, String flat) =>
    selected.contains(flat)
        ? selected.where((x) => x != flat).toList()
        : [...selected, flat];

/// "All visible" (web `selectAllFiltered`): union of selected + visible, keeping order.
List<String> selectAllVisible(List<String> selected, List<FlatOption> visible) {
  final out = List<String>.of(selected);
  for (final f in visible) {
    if (!out.contains(f.flatNumber)) out.add(f.flatNumber);
  }
  return out;
}

/// "Clear visible" (web `clearFiltered`).
List<String> clearVisible(List<String> selected, List<FlatOption> visible) {
  final nums = visible.map((f) => f.flatNumber).toSet();
  return selected.where((x) => !nums.contains(x)).toList();
}
