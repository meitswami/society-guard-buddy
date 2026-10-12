import 'gate_logic.dart';
import 'gate_models.dart';

/// Quick Entry logic ported from web `QuickEntryPage.tsx` and `src/lib/memberStaff.ts`.

/// Fixed household service roles (web `HOUSEHOLD_SERVICE_TYPES` without "Others").
const List<String> kKnownServiceTypesLc = [
  'cook',
  'maid',
  'washerman',
  'newspaper',
  'driver',
  'guard',
  'cleaner',
  'sweeper',
  'housekeeper',
  'mid-servant',
];

/// Family / household relations — never listed as staff.
const Set<String> kFamilyRelationsLc = {
  'owner',
  'spouse',
  'son',
  'daughter',
  'father',
  'mother',
  'brother',
  'sister',
  'tenant',
  'family',
  'other',
  'others',
};

/// Web `isQuickEntryStaffMember`: flat-registered servicemen (not the primary member).
bool isQuickEntryStaffMember(GateMember m) {
  if (m.isPrimary) return false;
  final r = m.relation.toLowerCase();
  if (r.isEmpty) return false;
  if (kKnownServiceTypesLc.contains(r)) return true;
  return !kFamilyRelationsLc.contains(r);
}

/// Stable synthetic phone when staff has no mobile (`visitors.phone` is NOT NULL).
String staffMemberSyntheticPhone(String memberId) {
  final compact = memberId.replaceAll('-', '');
  return 'staff-${compact.length > 16 ? compact.substring(0, 16) : compact}';
}

bool isSyntheticStaffPhone(String phone) => phone.startsWith('staff-');

/// Last 10 digits of the member phone, or the synthetic staff phone.
String quickEntryPhoneForMember(GateMember m) {
  final digits = (m.phone ?? '').replaceAll(RegExp(r'\D'), '');
  if (digits.length >= 10) return digits.substring(digits.length - 10);
  return staffMemberSyntheticPhone(m.id);
}

/// Title-cases each word like JS `replace(/\b\w/g, c => c.toUpperCase())`.
String titleCaseWords(String s) => s.replaceAllMapped(RegExp(r'\b\w'), (m) => m[0]!.toUpperCase());

/// Web `memberToQuickVisitorTemplate`.
GateVisitor memberToQuickVisitorTemplate(GateMember m, String flatNumber) {
  final rel = titleCaseWords(m.relation.isEmpty ? 'staff' : m.relation);
  return GateVisitor(
    id: 'member-${m.id}',
    name: m.name,
    phone: quickEntryPhoneForMember(m),
    documentType: 'other',
    documentNumber: '',
    visitorPhotos: m.photo != null && m.photo!.isNotEmpty ? [m.photo!] : const [],
    flatNumber: flatNumber,
    purpose: '$rel · Registered staff',
    entryTime: '',
    category: 'service',
  );
}

/// One person on the Quick Entry list.
class QuickRow {
  const QuickRow({required this.key, required this.visitor, required this.visitCount, required this.isStaff});

  final String key;

  /// Template used for a one-tap entry (latest visit, or the staff member).
  final GateVisitor visitor;
  final int visitCount;
  final bool isStaff;
}

class _RowBuilder {
  _RowBuilder(this.key, this.visitor, this.visitCount, this.isStaff);

  final String key;
  GateVisitor visitor;
  int visitCount;
  final bool isStaff;

  QuickRow build() => QuickRow(key: key, visitor: visitor, visitCount: visitCount, isStaff: isStaff);
}

int _localeCompare(String a, String b) {
  final c = a.toLowerCase().compareTo(b.toLowerCase());
  return c != 0 ? c : a.compareTo(b);
}

/// Registered staff + frequent visitors (2+ entries), keyed by phone, sorted by name.
List<QuickRow> buildQuickRows({
  required List<GateVisitor> visitors,
  required List<GateMember> members,
  required List<GateFlat> flats,
}) {
  final phoneMap = <String, ({GateVisitor visitor, int count})>{};
  for (final v in visitors) {
    final existing = phoneMap[v.phone];
    if (existing != null) {
      final latest = v.entryTime.compareTo(existing.visitor.entryTime) > 0 ? v : existing.visitor;
      phoneMap[v.phone] = (visitor: latest, count: existing.count + 1);
    } else {
      phoneMap[v.phone] = (visitor: v, count: 1);
    }
  }
  final frequent = phoneMap.values.where((e) => e.count >= 2).toList()..sort((a, b) => b.count.compareTo(a.count));

  final flatNumberById = {for (final f in flats) f.id: f.flatNumber};
  final byPhone = <String, _RowBuilder>{};

  for (final m in members) {
    if (!isQuickEntryStaffMember(m)) continue;
    final flatNumber = flatNumberById[m.flatId];
    if (flatNumber == null || flatNumber.isEmpty) continue;
    final visitor = memberToQuickVisitorTemplate(m, flatNumber);
    byPhone[visitor.phone] = _RowBuilder('staff-${m.id}', visitor, 0, true);
  }

  for (final e in frequent) {
    final v = e.visitor;
    final existing = byPhone[v.phone];
    if (existing != null) {
      existing.visitCount = e.count;
      if (existing.visitor.visitorPhotos.isEmpty && v.visitorPhotos.isNotEmpty) {
        existing.visitor = existing.visitor.copyWith(visitorPhotos: v.visitorPhotos);
      }
    } else {
      byPhone[v.phone] = _RowBuilder('freq-${v.phone}', v, e.count, false);
    }
  }

  final rows = byPhone.values.map((b) => b.build()).toList()
    ..sort((a, b) => _localeCompare(a.visitor.name, b.visitor.name));
  return rows;
}

/// Web `rowMatchesSearch` — [q] is the trimmed, lower-cased query.
bool quickRowMatchesSearch(QuickRow row, String q) {
  final v = row.visitor;
  return v.name.toLowerCase().contains(q) ||
      v.phone.contains(q) ||
      v.flatNumber.toLowerCase().contains(q) ||
      v.purpose.toLowerCase().contains(q);
}

List<QuickRow> filterQuickRows(List<QuickRow> rows, String search) {
  final q = search.trim().toLowerCase();
  if (q.isEmpty) return rows;
  return rows.where((r) => quickRowMatchesSearch(r, q)).toList();
}

/// Web `findActiveVisit`: the open visit of this person (same phone, else same name + flat).
GateVisitor? findActiveVisit(List<GateVisitor> visitors, GateVisitor template) {
  final inside = visitors.where((v) => v.isInside).toList();
  for (final v in inside) {
    if (v.phone == template.phone) return v;
  }
  final nameLc = template.name.trim().toLowerCase();
  final flat = template.flatNumber.trim().toLowerCase();
  for (final v in inside) {
    if (v.flatNumber.trim().toLowerCase() == flat && v.name.trim().toLowerCase() == nameLc) return v;
  }
  return null;
}

/// Web `quickLog`: a new entry copied from [source].
GateVisitor buildQuickEntry({
  required GateVisitor source,
  required String guardId,
  required String guardName,
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  return GateVisitor(
    id: 'Q${at.millisecondsSinceEpoch}',
    name: source.name,
    phone: source.phone,
    documentType: source.documentType,
    documentNumber: source.documentNumber,
    visitorPhotos: source.visitorPhotos,
    flatNumber: source.flatNumber,
    purpose: source.purpose.isEmpty ? 'Regular Visit' : source.purpose,
    entryTime: nowIsoUtc(at),
    guardId: guardId,
    guardName: guardName,
    category: source.category,
    company: source.company,
  );
}
