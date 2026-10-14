import 'js_compat.dart';

/// Port of `src/lib/flatMultiSelectOptions.ts`.

/// Option shown in the flat multi-select grid (web `FlatMultiSelectOption`).
class FlatOption {
  const FlatOption({required this.id, required this.flatNumber, this.subtitle});

  final String id;
  final String flatNumber;

  /// Shown under the flat number (primary member or owner).
  final String? subtitle;
}

/// Minimal flat row (`flats.select('flat_number, id, owner_name, is_occupied')`).
class FlatLite {
  const FlatLite({required this.id, required this.flatNumber, this.ownerName, this.isOccupied});

  final String id;
  final String flatNumber;
  final String? ownerName;
  final bool? isOccupied;

  factory FlatLite.fromJson(Map<String, dynamic> j) => FlatLite(
        id: '${j['id'] ?? ''}',
        flatNumber: '${j['flat_number'] ?? ''}',
        ownerName: j['owner_name']?.toString(),
        isOccupied: j['is_occupied'] is bool ? j['is_occupied'] as bool : null,
      );
}

/// Numeric flat order (101, 102, … 605) — not lexicographic string order.
int compareFlatNumbers(String a, String b) => naturalCompare(a, b);

List<T> sortFlatsByNumber<T>(Iterable<T> flats, String Function(T) flatNumberOf) =>
    stableSorted(flats, (a, b) => compareFlatNumbers(flatNumberOf(a), flatNumberOf(b)));

/// Build options with a second-line label: primary member name, else flat owner_name.
List<FlatOption> flatOptionsWithPrimaryLabel(List<FlatLite> flats, Map<String, String> primaryNameByFlatId) {
  return [
    for (final f in sortFlatsByNumber<FlatLite>(flats, (x) => x.flatNumber))
      FlatOption(
        id: f.id,
        flatNumber: f.flatNumber,
        subtitle: _firstNonEmpty(primaryNameByFlatId[f.id]?.trim(), f.ownerName?.trim()),
      ),
  ];
}

String? _firstNonEmpty(String? a, String? b) {
  if (a != null && a.isNotEmpty) return a;
  if (b != null && b.isNotEmpty) return b;
  return null;
}

/// Label stored on payment rows: one value per flat, no shared multi-select field.
String? residentLabelForFlatRow(String? flatId, String? ownerName, Map<String, String> primaryNameByFlatId) {
  if (flatId != null && flatId.isNotEmpty) {
    final p = primaryNameByFlatId[flatId]?.trim();
    if (p != null && p.isNotEmpty) return p;
  }
  final o = ownerName?.trim();
  return (o == null || o.isEmpty) ? null : o;
}
