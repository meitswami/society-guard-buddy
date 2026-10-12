import 'js_compat.dart';

/// Port of the sort helpers in `src/lib/flatMultiSelectOptions.ts`.

/// Numeric flat order (101, 102, … 605) — not lexicographic string order.
int compareFlatNumbers(String? a, String? b) =>
    jsLocaleCompare(a ?? '', b ?? '', numeric: true);

List<T> sortFlatsByNumber<T>(
    Iterable<T> flats, String Function(T) flatNumberOf) {
  final list = flats.toList();
  list.sort((a, b) => compareFlatNumbers(flatNumberOf(a), flatNumberOf(b)));
  return list;
}

/// Numeric flat order when both rows have a flat; otherwise chronological.
int compareByFlatThenDate(
    String? flatA, String? flatB, String dateA, String dateB) {
  final fa = flatA ?? '', fb = flatB ?? '';
  if (fa.isNotEmpty && fb.isNotEmpty) {
    final byFlat = compareFlatNumbers(fa, fb);
    if (byFlat != 0) return byFlat;
  }
  final byDate = jsLocaleCompare(dateA, dateB);
  if (byDate != 0) return byDate;
  return compareFlatNumbers(fa, fb);
}
