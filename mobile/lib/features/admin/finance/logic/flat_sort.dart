// Port of `src/lib/flatMultiSelectOptions.ts`.

import 'finance_format.dart';
import 'finance_models.dart';

/// Numeric flat order (101, 102, … 605) — not lexicographic string order.
int compareFlatNumbers(String a, String b) => compareNatural(a, b);

List<T> sortFlatsByNumber<T>(
    Iterable<T> flats, String Function(T) flatNumberOf) {
  final list = [...flats];
  list.sort((a, b) => compareFlatNumbers(flatNumberOf(a), flatNumberOf(b)));
  return list;
}

/// Lowest flat number on a ledger allocation list (for sort keys).
String primaryFlatFromAllocations(List<FinanceAllocation>? allocations) {
  if (allocations == null || allocations.isEmpty) return '';
  return sortFlatsByNumber<FinanceAllocation>(allocations, (a) => a.flatNumber)
      .first
      .flatNumber;
}

/// Numeric flat order when both rows have a flat; otherwise chronological.
int compareByFlatThenDate(
    String flatA, String flatB, String dateA, String dateB) {
  if (flatA.isNotEmpty && flatB.isNotEmpty) {
    final byFlat = compareFlatNumbers(flatA, flatB);
    if (byFlat != 0) return byFlat;
  }
  final byDate = compareText(dateA, dateB);
  if (byDate != 0) return byDate;
  return compareFlatNumbers(flatA, flatB);
}

/// Option shown in the flat multi-select (`subtitle` = primary member, else owner).
class FlatOption {
  const FlatOption({required this.id, required this.flatNumber, this.subtitle});

  final String id;
  final String flatNumber;
  final String? subtitle;
}

/// Web `flatOptionsWithPrimaryLabel`.
List<FlatOption> flatOptionsWithPrimaryLabel(
    List<SocietyFlatRow> flats, Map<String, String> primaryNameByFlatId) {
  return sortFlatsByNumber<SocietyFlatRow>(flats, (f) => f.flatNumber).map((f) {
    final primary = primaryNameByFlatId[f.id]?.trim();
    final owner = f.ownerName?.trim();
    final subtitle = (primary != null && primary.isNotEmpty)
        ? primary
        : (owner != null && owner.isNotEmpty ? owner : null);
    return FlatOption(id: f.id, flatNumber: f.flatNumber, subtitle: subtitle);
  }).toList();
}

/// Label stored on payment rows: primary member name, else flat owner_name, else null.
String? residentLabelForFlatRow(String? flatId, String? ownerName,
    Map<String, String> primaryNameByFlatId) {
  if (flatId != null && flatId.isNotEmpty) {
    final p = primaryNameByFlatId[flatId]?.trim();
    if (p != null && p.isNotEmpty) return p;
  }
  final o = ownerName?.trim();
  return (o == null || o.isEmpty) ? null : o;
}
