/// Committee roster protection — port of web `src/lib/committeeProtection.ts` and the
/// term helpers of `src/lib/committeeMember.ts` that the resident dashboard uses
/// (`currentCommitteeMembers`). Members on the roster are admin-only edits.
library;

class CommitteeRosterRow {
  const CommitteeRosterRow({
    required this.id,
    required this.name,
    required this.position,
    this.phone,
    this.flatId,
    this.flatNumber,
    this.flatOwnerName,
    this.termFrom,
    this.termTo,
    this.sortOrder = 0,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String position;
  final String? phone;
  final String? flatId;
  final String? flatNumber;
  final String? flatOwnerName;
  final String? termFrom;
  final String? termTo;
  final int sortOrder;
  final bool isActive;

  factory CommitteeRosterRow.fromJson(Map<String, dynamic> r) {
    String? s(Object? v) => v?.toString();
    final so = r['sort_order'];
    return CommitteeRosterRow(
      id: (r['id'] ?? '').toString(),
      name: (r['name'] ?? '').toString(),
      position: (r['position'] ?? '').toString(),
      phone: s(r['phone']),
      flatId: s(r['flat_id']),
      flatNumber: s(r['flat_number']),
      flatOwnerName: s(r['flat_owner_name']),
      termFrom: s(r['term_from']),
      termTo: s(r['term_to']),
      sortOrder: so is num ? so.toInt() : int.tryParse('${so ?? ''}') ?? 0,
      isActive: r['is_active'] != false,
    );
  }
}

String _norm(String? s) => (s ?? '').trim().toLowerCase();

String? _ymd(String? v) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return null;
  return s.length >= 10 ? s.substring(0, 10) : s;
}

/// Insertion-stable sort (JS `Array.prototype.sort` is stable).
List<T> _stableSorted<T>(List<T> items, int Function(T a, T b) compare) {
  final indexed = [for (var i = 0; i < items.length; i++) (i, items[i])];
  indexed.sort((a, b) {
    final c = compare(a.$2, b.$2);
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}

String? latestCommitteeTermFrom(List<CommitteeRosterRow> rows) {
  String? latest;
  for (final r in rows) {
    final from = _ymd(r.termFrom);
    if (from != null && (latest == null || from.compareTo(latest) > 0)) latest = from;
  }
  return latest;
}

/// Latest elected / appointed term is "current", even if `term_from` is a few days ahead.
bool isCurrentCommitteeTerm(CommitteeRosterRow row, String? currentTermFrom) {
  if (currentTermFrom == null) return true;
  final from = _ymd(row.termFrom);
  if (from != null) return from.compareTo(currentTermFrom) >= 0;
  final to = _ymd(row.termTo);
  if (to != null && to.compareTo(currentTermFrom) < 0) return false;
  return true;
}

const _uniquePosts = {'president', 'vice-president', 'secretary', 'treasurer', 'cultural secretary'};

String _personKey(String name) => name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Collapse duplicate office-bearers in one term (web `dedupeCommitteeByPosition`).
List<CommitteeRosterRow> dedupeCommitteeByPosition(List<CommitteeRosterRow> rows) {
  final groups = <String, List<CommitteeRosterRow>>{};
  for (final r in rows) {
    final pos = r.position.trim().toLowerCase();
    final key = _uniquePosts.contains(pos) ? pos : '$pos|${_personKey(r.name)}';
    groups.putIfAbsent(key, () => []).add(r);
  }
  final out = <CommitteeRosterRow>[];
  for (final list in groups.values) {
    if (list.length == 1) {
      out.add(list.first);
      continue;
    }
    final sorted = _stableSorted<CommitteeRosterRow>(list, (a, b) {
      final aTo = (a.termTo ?? '').isNotEmpty ? 1 : 0;
      final bTo = (b.termTo ?? '').isNotEmpty ? 1 : 0;
      if (aTo != bTo) return bTo - aTo;
      final al = a.name.trim().length, bl = b.name.trim().length;
      if (al != bl) return bl - al;
      return a.sortOrder - b.sortOrder;
    });
    out.add(sorted.first);
  }
  return _stableSorted<CommitteeRosterRow>(out, (a, b) {
    final c = a.sortOrder - b.sortOrder;
    return c != 0 ? c : a.name.compareTo(b.name);
  });
}

class CommitteeTermSplit {
  const CommitteeTermSplit({required this.current, required this.previous, required this.currentTermFrom});
  final List<CommitteeRosterRow> current;
  final List<CommitteeRosterRow> previous;
  final String? currentTermFrom;
}

/// Split the active roster into the current term vs earlier terms.
CommitteeTermSplit splitCommitteeTerms(List<CommitteeRosterRow> rows) {
  final active = rows.where((r) => r.isActive).toList();
  final currentFrom = latestCommitteeTermFrom(active);
  final current = <CommitteeRosterRow>[];
  final previous = <CommitteeRosterRow>[];
  for (final r in active) {
    if (isCurrentCommitteeTerm(r, currentFrom)) {
      current.add(r);
    } else {
      previous.add(r);
    }
  }
  return CommitteeTermSplit(
      current: dedupeCommitteeByPosition(current), previous: previous, currentTermFrom: currentFrom);
}

List<CommitteeRosterRow> currentCommitteeMembers(List<CommitteeRosterRow> rows) => splitCommitteeTerms(rows).current;

/// True when this household member appears on the published committee roster (admin-only edits).
bool isMemberOnCommitteeRoster({
  String? id,
  String? name,
  String? phone,
  String? flatId,
  required List<CommitteeRosterRow> roster,
}) {
  final n = _norm(name);
  final p = (phone ?? '').replaceAll(RegExp(r'\D'), '');
  final f = flatId ?? '';
  for (final row in roster) {
    final rowFlat = row.flatId ?? '';
    if (f.isNotEmpty && rowFlat.isNotEmpty && rowFlat == f && n.isNotEmpty && _norm(row.name) == n) return true;
    if (f.isNotEmpty && rowFlat.isNotEmpty && rowFlat == f && n.isNotEmpty && _norm(row.flatOwnerName) == n) {
      return true;
    }
    if (p.isNotEmpty && (row.phone ?? '').isNotEmpty && row.phone!.replaceAll(RegExp(r'\D'), '') == p) return true;
    if ((id ?? '').isNotEmpty && row.flatId == f) {
      if (_norm(row.name) == n || _norm(row.flatOwnerName) == n) return true;
    }
  }
  return false;
}
