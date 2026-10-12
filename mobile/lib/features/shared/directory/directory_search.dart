import 'directory_models.dart';

/// Pure search / grouping rules of web `src/pages/DirectoryPage.tsx` and the resident
/// directory tab of `src/pages/ResidentDashboard.tsx`.

String _joinTruthy(Iterable<String?> parts) =>
    parts.where((p) => p != null && p.isNotEmpty).cast<String>().join(' ');

Map<String, List<PeopleMember>> membersByFlatId(
    Iterable<PeopleMember> members) {
  final map = <String, List<PeopleMember>>{};
  for (final m in members) {
    (map[m.flatId] ??= []).add(m);
  }
  return map;
}

Map<String, List<PeopleVehicle>> vehiclesByFlatNumber(
    Iterable<PeopleVehicle> vehicles) {
  final map = <String, List<PeopleVehicle>>{};
  for (final v in vehicles) {
    (map[v.flatNumber] ??= []).add(v);
  }
  return map;
}

/// Guard / admin directory (flats view) — web `filteredFlats`.
List<PeopleFlat> filterDirectoryFlats({
  required List<PeopleFlat> flats,
  required Map<String, List<PeopleMember>> membersByFlat,
  required Map<String, List<PeopleVehicle>> vehiclesByFlat,
  required String query,
}) {
  if (query.trim().isEmpty) return flats;
  final q = query.toLowerCase();
  return flats.where((f) {
    final flatMembers = membersByFlat[f.id] ?? const [];
    final flatVehicles = vehiclesByFlat[f.flatNumber] ?? const [];
    final memberText = flatMembers
        .map((m) => _joinTruthy([
              m.name,
              m.phone,
              m.whatsappPhone,
              m.email,
              m.relation,
              m.age?.toString() ?? '',
              m.gender
            ]))
        .join(' ');
    final vehicleText = flatVehicles
        .map((v) =>
            _joinTruthy([v.vehicleNumber, v.vehicleType, v.residentName]))
        .join(' ');
    final haystack = [
      f.flatNumber,
      f.ownerName ?? '',
      f.ownerPhone ?? '',
      f.wing ?? '',
      f.floor ?? '',
      f.flatType,
      memberText,
      vehicleText,
    ].join(' ').toLowerCase();
    return haystack.contains(q);
  }).toList();
}

/// When searching by name, surface matching people (with photos) on the flat row
/// (guard / admin directory: name, phone, WhatsApp, email, relation).
List<PeopleMember> directoryNameHits(
    List<PeopleMember> flatMembers, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  return flatMembers
      .where((m) =>
          _joinTruthy([m.name, m.phone, m.whatsappPhone, m.email, m.relation])
              .toLowerCase()
              .contains(q))
      .toList();
}

/// Resident directory tab — web `filteredDirFlats`.
List<PeopleFlat> filterResidentDirectoryFlats({
  required List<PeopleFlat> flats,
  required Map<String, List<PeopleMember>> membersByFlat,
  required Map<String, List<PeopleVehicle>> vehiclesByFlat,
  required String query,
}) {
  if (query.trim().isEmpty) return flats;
  final q = query.toLowerCase();
  return flats.where((f) {
    final flatMembers = membersByFlat[f.id] ?? const [];
    final flatVehicles = vehiclesByFlat[f.flatNumber] ?? const [];
    final memberText = flatMembers
        .map((m) => _joinTruthy(
            [m.name, m.phone, m.relation, m.age?.toString() ?? '', m.gender]))
        .join(' ')
        .toLowerCase();
    final vehicleText = flatVehicles
        .map((v) =>
            _joinTruthy([v.vehicleNumber, v.vehicleType, v.residentName]))
        .join(' ')
        .toLowerCase();
    final haystack = [
      f.flatNumber,
      f.ownerName ?? '',
      f.ownerPhone ?? '',
      f.wing ?? '',
      f.floor ?? '',
      memberText,
      vehicleText,
    ].join(' ').toLowerCase();
    return haystack.contains(q);
  }).toList();
}

/// Resident directory name hits (name, phone, relation).
List<PeopleMember> residentNameHits(
    List<PeopleMember> flatMembers, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  return flatMembers
      .where((m) =>
          _joinTruthy([m.name, m.phone, m.relation]).toLowerCase().contains(q))
      .toList();
}

/// Web `visitorDirectory`: one entry per phone with latest visit, total visits and first visit,
/// newest first.
List<VisitorDirectoryEntry> buildVisitorDirectory(
    List<DirectoryVisitor> visitors) {
  final byPhone = <String, VisitorDirectoryEntry>{};
  for (final v in visitors) {
    final existing = byPhone[v.phone];
    if (existing != null) {
      existing.totalVisits++;
      if (v.entryTime.compareTo(existing.latest.entryTime) > 0)
        existing.latest = v;
      if (v.entryTime.compareTo(existing.firstVisit) < 0)
        existing.firstVisit = v.entryTime;
    } else {
      byPhone[v.phone] = VisitorDirectoryEntry(
          latest: v, totalVisits: 1, firstVisit: v.entryTime);
    }
  }
  final list = byPhone.values.toList();
  // Stable: Array.prototype.sort is stable in modern engines.
  final indexed = list.asMap().entries.toList()
    ..sort((a, b) {
      final c = b.value.latest.entryTime.compareTo(a.value.latest.entryTime);
      return c != 0 ? c : a.key.compareTo(b.key);
    });
  return indexed.map((e) => e.value).toList();
}

/// Web `filteredVisitors`.
List<VisitorDirectoryEntry> filterVisitorDirectory(
    List<VisitorDirectoryEntry> entries, String query) {
  if (query.trim().isEmpty) return entries;
  final q = query.toLowerCase();
  return entries.where((e) {
    final v = e.latest;
    return v.name.toLowerCase().contains(q) ||
        v.phone.contains(q) ||
        v.flatNumber.toLowerCase().contains(q) ||
        (v.vehicleNumber != null && v.vehicleNumber!.toLowerCase().contains(q));
  }).toList();
}

/// Numeric flat order (101, 102, … 605) — web `compareFlatNumbers`
/// (`localeCompare(b, undefined, { numeric: true })`).
int compareFlatNumbers(String a, String b) {
  final re = RegExp(r'\d+|\D+');
  final pa = re.allMatches(a).map((m) => m.group(0)!).toList();
  final pb = re.allMatches(b).map((m) => m.group(0)!).toList();
  for (var i = 0; i < pa.length && i < pb.length; i++) {
    final x = pa[i], y = pb[i];
    final xd = RegExp(r'^\d+$').hasMatch(x), yd = RegExp(r'^\d+$').hasMatch(y);
    int c;
    if (xd && yd) {
      c = BigInt.parse(x).compareTo(BigInt.parse(y));
    } else if (xd != yd) {
      // Digits sort before letters in ICU collation.
      c = xd ? -1 : 1;
    } else {
      c = x.toLowerCase().compareTo(y.toLowerCase());
    }
    if (c != 0) return c;
  }
  final lc = pa.length.compareTo(pb.length);
  if (lc != 0) return lc;
  return a.compareTo(b);
}

List<T> sortByFlatNumber<T>(List<T> items, String Function(T) flatNumberOf) => [
      ...items
    ]..sort((a, b) => compareFlatNumbers(flatNumberOf(a), flatNumberOf(b)));
