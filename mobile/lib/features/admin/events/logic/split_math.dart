import 'js_compat.dart';

/// Ports of `src/lib/equalSplitAmounts.ts` and `src/lib/flatHeadcountSplit.ts`.

class FlatShare {
  const FlatShare(this.flatNumber, this.amount);

  final String flatNumber;
  final double amount;

  @override
  String toString() => 'FlatShare($flatNumber, $amount)';
}

/// Equal per-flat amounts that always sum exactly to `total` (remainder on last row).
List<FlatShare> computeEqualSplitAmounts(num total, List<String> flatNumbers) {
  if (flatNumbers.isEmpty) return const [];
  final share = round2(total / flatNumbers.length);
  var allocated = 0.0;
  final out = <FlatShare>[];
  for (var i = 0; i < flatNumbers.length; i++) {
    final isLast = i == flatNumbers.length - 1;
    final amount = isLast ? round2(total - allocated) : share;
    allocated += amount;
    out.add(FlatShare(flatNumbers[i], amount));
  }
  return out;
}

/// Nudge the last split so row amounts sum to `total` (handles rounding drift).
List<double> adjustSplitRemainder(num total, List<double> amounts) {
  if (amounts.isEmpty) return const [];
  final sum = round2(amounts.fold<double>(0, (a, b) => a + b));
  final diff = round2(total - sum);
  if (diff.abs() < 0.005) return amounts;
  final out = [...amounts];
  out[out.length - 1] = round2(out[out.length - 1] + diff);
  return out;
}

/// Member row used for headcount splits (`members.select('id, flat_id, name, age, relation')`).
class FlatMemberRow {
  const FlatMemberRow({this.id, this.flatId, this.name, this.age, this.relation});

  final String? id;
  final String? flatId;
  final String? name;
  final num? age;
  final String? relation;

  factory FlatMemberRow.fromJson(Map<String, dynamic> j) => FlatMemberRow(
        id: j['id']?.toString(),
        flatId: j['flat_id']?.toString(),
        name: j['name']?.toString(),
        age: j['age'] is num ? j['age'] as num : num.tryParse('${j['age'] ?? ''}'),
        relation: j['relation']?.toString(),
      );
}

class FlatHeadcount {
  const FlatHeadcount({required this.flatNumber, required this.adults, required this.kids, required this.units});

  final String flatNumber;
  final int adults;
  final int kids;
  final double units;
}

const List<String> kChildRelationHints = ['son', 'daughter', 'child', 'kid', 'minor', 'grandson', 'granddaughter'];

bool isChildMember(FlatMemberRow m) {
  final age = m.age;
  if (age != null && !age.isNaN && age > 0) return age < 18;
  final rel = (m.relation ?? '').trim().toLowerCase();
  if (rel.isEmpty) return false;
  return kChildRelationHints.any((hint) => rel == hint || rel.contains(hint));
}

/// Per-flat adults, kids, and weighted units for event/function cost sharing.
FlatHeadcount headcountForFlat(
  String flatNumber,
  String? flatId,
  List<FlatMemberRow> members,
  num adultWeight,
  num childWeight,
) {
  final flatMembers = <FlatMemberRow>[
    for (final m in members)
      if (flatId != null && flatId.isNotEmpty && m.flatId == flatId) m,
  ];
  return headcountFromFlatMembers(flatNumber, flatMembers, adultWeight, childWeight);
}

/// Same as [headcountForFlat] when the members are already filtered to the flat.
FlatHeadcount headcountFromFlatMembers(
  String flatNumber,
  List<FlatMemberRow> flatMembers,
  num adultWeight,
  num childWeight,
) {
  if (flatMembers.isEmpty) {
    return FlatHeadcount(flatNumber: flatNumber, adults: 1, kids: 0, units: adultWeight.toDouble());
  }
  var adults = 0;
  var kids = 0;
  for (final m in flatMembers) {
    if (isChildMember(m)) {
      kids += 1;
    } else {
      adults += 1;
    }
  }
  if (adults == 0 && kids == 0) adults = 1;
  final units = adults * adultWeight + kids * childWeight;
  return FlatHeadcount(flatNumber: flatNumber, adults: adults, kids: kids, units: units.toDouble());
}

class HeadcountAmount {
  const HeadcountAmount({required this.flatNumber, required this.amount, required this.adults, required this.kids});

  final String flatNumber;
  final double amount;
  final int adults;
  final int kids;
}

List<HeadcountAmount> computeHeadcountAmounts(num total, List<FlatHeadcount> rows) {
  final unitSum = rows.fold<double>(0, (s, r) => s + r.units);
  if (unitSum <= 0) return const [];
  var allocated = 0.0;
  final out = <HeadcountAmount>[];
  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    final isLast = i == rows.length - 1;
    final amount = isLast ? round2(total - allocated) : round2((total * row.units) / unitSum);
    allocated += amount;
    out.add(HeadcountAmount(flatNumber: row.flatNumber, amount: amount, adults: row.adults, kids: row.kids));
  }
  return out;
}

/// Members grouped by `flat_id` so per-flat headcounts are cheap in large societies.
class MemberIndex {
  MemberIndex(List<FlatMemberRow> members) {
    for (final m in members) {
      final id = m.flatId;
      if (id == null || id.isEmpty) continue;
      (_byFlat[id] ??= <FlatMemberRow>[]).add(m);
    }
  }

  final Map<String, List<FlatMemberRow>> _byFlat = {};

  FlatHeadcount headcount(String flatNumber, String? flatId, num adultWeight, num childWeight) =>
      headcountFromFlatMembers(flatNumber, flatId == null ? const [] : (_byFlat[flatId] ?? const []), adultWeight, childWeight);
}
