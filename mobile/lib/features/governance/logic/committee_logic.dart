/// Port of web `src/lib/committeeMember.ts`, `committeeProtection.ts` and
/// `committeeDuty.ts`.
library;

import 'text_compare.dart';

/// `committee_members.selection_type`.
enum CommitteeSelectionType {
  elected('elected', 'Elected', 'निर्वाचित'),
  nominated('nominated', 'Nominated', 'मनोनीत'),
  runnerUp('runner_up', 'Runner-up (2nd/3rd)', 'उपविजेता (द्वितीय/तृतीय)'),
  voluntary('voluntary', 'Voluntary', 'स्वैच्छिक'),
  executiveProposed('executive_proposed', 'Executive proposed', 'कार्यकारिणी प्रस्तावित');

  const CommitteeSelectionType(this.value, this.labelEn, this.labelHi);

  final String value;
  final String labelEn;
  final String labelHi;

  String label(bool hi) => hi ? labelHi : labelEn;

  static CommitteeSelectionType? parse(Object? raw) {
    for (final t in values) {
      if (t.value == raw) return t;
    }
    return null;
  }
}

/// Web `selectionTypeLabel` (`—` for unknown / null).
String selectionTypeLabel(Object? type, {bool hi = false}) => CommitteeSelectionType.parse(type)?.label(hi) ?? '—';

/// Row of `committee_members`.
class CommitteeMemberRow {
  CommitteeMemberRow({
    required this.id,
    required this.societyId,
    required this.name,
    required this.position,
    this.phone,
    this.gender,
    this.photo,
    this.showRepresentative = false,
    this.repName,
    this.repPhone,
    this.repPhoto,
    this.sortOrder = 0,
    this.isActive = true,
    this.flatId,
    this.flatNumber,
    this.flatOwnerName,
    this.termFrom,
    this.termTo,
    this.selectionType,
    this.sourcePollId,
    this.sourceOptionId,
  });

  final String id;
  final String societyId;
  final String name;
  final String position;
  final String? phone;
  final String? gender;

  /// May be replaced with the live household photo after load (web does the same).
  String? photo;
  final bool showRepresentative;
  final String? repName;
  final String? repPhone;
  final String? repPhoto;
  final int sortOrder;
  final bool isActive;
  final String? flatId;
  final String? flatNumber;
  final String? flatOwnerName;
  final String? termFrom;
  final String? termTo;
  final String? selectionType;
  final String? sourcePollId;
  final String? sourceOptionId;

  factory CommitteeMemberRow.fromJson(Map<String, dynamic> j) {
    final so = j['sort_order'];
    return CommitteeMemberRow(
      id: '${j['id']}',
      societyId: '${j['society_id'] ?? ''}',
      name: (j['name'] ?? '').toString(),
      position: (j['position'] ?? '').toString(),
      phone: j['phone'] as String?,
      gender: j['gender'] as String?,
      photo: j['photo'] as String?,
      showRepresentative: j['show_representative'] == true,
      repName: j['rep_name'] as String?,
      repPhone: j['rep_phone'] as String?,
      repPhoto: j['rep_photo'] as String?,
      sortOrder: so is num ? so.toInt() : int.tryParse('$so') ?? 0,
      isActive: j['is_active'] != false,
      flatId: j['flat_id'] as String?,
      flatNumber: j['flat_number'] as String?,
      flatOwnerName: j['flat_owner_name'] as String?,
      termFrom: j['term_from'] as String?,
      termTo: j['term_to'] as String?,
      selectionType: j['selection_type'] as String?,
      sourcePollId: j['source_poll_id'] as String?,
      sourceOptionId: j['source_option_id'] as String?,
    );
  }
}

String? _slice10(String? s) {
  if (s == null || s.isEmpty) return null;
  return s.length > 10 ? s.substring(0, 10) : s;
}

/// True when the post holder name differs from the flat owner (representative serving the post).
bool committeeIsRepresentative({required String name, String? flatOwnerName}) {
  final owner = (flatOwnerName ?? '').trim();
  final holder = name.trim();
  if (owner.isEmpty || holder.isEmpty) return false;
  return owner.toLowerCase() != holder.toLowerCase();
}

class CommitteeDisplayLabels {
  const CommitteeDisplayLabels({required this.primaryName, required this.subtitle, required this.isRepresentative});

  final String primaryName;
  final String? subtitle;
  final bool isRepresentative;
}

/// Primary label + optional subtitle for cards and lists (web `committeeDisplayLabels`).
CommitteeDisplayLabels committeeDisplayLabels(CommitteeMemberRow row, {bool hi = false}) {
  final isRep = committeeIsRepresentative(name: row.name, flatOwnerName: row.flatOwnerName);
  final owner = (row.flatOwnerName ?? '').trim();
  final holder = row.name.trim();
  final flatLabel = (row.flatNumber != null && row.flatNumber!.isNotEmpty)
      ? (hi ? 'फ्लैट ${row.flatNumber}' : 'Flat ${row.flatNumber}')
      : null;
  if (isRep) {
    final parts = [flatLabel, if (owner.isNotEmpty) (hi ? 'स्वामी: $owner' : 'Owner: $owner')].whereType<String>();
    final sub = parts.join(' · ');
    return CommitteeDisplayLabels(primaryName: holder, subtitle: sub.isEmpty ? null : sub, isRepresentative: true);
  }
  return CommitteeDisplayLabels(
    primaryName: owner.isNotEmpty ? owner : holder,
    subtitle: flatLabel,
    isRepresentative: false,
  );
}

/// `from → to` or `from → Until retirement` (web `committeeTenureLabel`).
String? committeeTenureLabel({String? termFrom, String? termTo, bool hi = false}) {
  final from = _slice10(termFrom);
  if (from == null) return null;
  final to = _slice10(termTo);
  return to != null ? '$from → $to' : '$from → ${hi ? 'सेवानिवृत्ति तक' : 'Until retirement'}';
}

String _pad2(int n) => n.toString().padLeft(2, '0');

/// Local calendar `yyyy-MM-dd` (society tenure is date-based, not UTC midnight).
String localIsoDate([DateTime? d]) {
  final x = d ?? DateTime.now();
  return '${x.year}-${_pad2(x.month)}-${_pad2(x.day)}';
}

String? termStartIso(String? termFrom) => _slice10(termFrom);

/// Latest `term_from` among rows.
String? latestCommitteeTermFrom(Iterable<String?> termFroms) {
  String? latest;
  for (final f in termFroms) {
    final from = _slice10(f);
    if (from != null && (latest == null || from.compareTo(latest) > 0)) latest = from;
  }
  return latest;
}

/// Latest elected/appointed term is "current", even if term_from is a few days in the future.
bool isCurrentCommitteeTerm({String? termFrom, String? termTo, String? currentTermFrom}) {
  if (currentTermFrom == null) return true;
  final from = _slice10(termFrom);
  if (from != null) return from.compareTo(currentTermFrom) >= 0;
  final to = _slice10(termTo);
  if (to != null && to.compareTo(currentTermFrom) < 0) return false;
  return true;
}

const Set<String> _uniquePosts = {'president', 'vice-president', 'secretary', 'treasurer', 'cultural secretary'};

String _normalizePersonKey(String name) => name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Collapse accidental duplicate office-bearers in the same term.
/// Unique posts keep one row (prefer a closed tenure, then longer name).
List<CommitteeMemberRow> dedupeCommitteeByPosition(List<CommitteeMemberRow> rows) {
  final groups = <String, List<CommitteeMemberRow>>{};
  final order = <String>[];
  for (final r in rows) {
    final pos = r.position.trim().toLowerCase();
    final key = _uniquePosts.contains(pos) ? pos : '$pos|${_normalizePersonKey(r.name)}';
    if (!groups.containsKey(key)) order.add(key);
    groups.putIfAbsent(key, () => []).add(r);
  }
  final out = <CommitteeMemberRow>[];
  for (final key in order) {
    final list = groups[key]!;
    if (list.length == 1) {
      out.add(list.first);
      continue;
    }
    final indexed = [for (var i = 0; i < list.length; i++) (i, list[i])];
    indexed.sort((a, b) {
      final aTo = (a.$2.termTo != null && a.$2.termTo!.isNotEmpty) ? 1 : 0;
      final bTo = (b.$2.termTo != null && b.$2.termTo!.isNotEmpty) ? 1 : 0;
      if (aTo != bTo) return bTo - aTo;
      final la = a.$2.name.trim().length;
      final lb = b.$2.name.trim().length;
      if (lb != la) return lb - la;
      final so = a.$2.sortOrder - b.$2.sortOrder;
      return so != 0 ? so : a.$1.compareTo(b.$1);
    });
    out.add(indexed.first.$2);
  }
  final indexedOut = [for (var i = 0; i < out.length; i++) (i, out[i])];
  indexedOut.sort((a, b) {
    final so = a.$2.sortOrder - b.$2.sortOrder;
    if (so != 0) return so;
    final n = localeCompare(a.$2.name, b.$2.name);
    return n != 0 ? n : a.$1.compareTo(b.$1);
  });
  return indexedOut.map((e) => e.$2).toList();
}

class CommitteeTermSplit {
  const CommitteeTermSplit({required this.current, required this.previous, required this.currentTermFrom});

  final List<CommitteeMemberRow> current;
  final List<CommitteeMemberRow> previous;
  final String? currentTermFrom;
}

/// Split the active roster into current term vs earlier terms ("Previous year").
CommitteeTermSplit splitCommitteeTerms(List<CommitteeMemberRow> rows) {
  final active = rows.where((r) => r.isActive).toList();
  final currentTermFrom = latestCommitteeTermFrom(active.map((r) => r.termFrom));
  final current = <CommitteeMemberRow>[];
  final previous = <CommitteeMemberRow>[];
  for (final r in active) {
    if (isCurrentCommitteeTerm(termFrom: r.termFrom, termTo: r.termTo, currentTermFrom: currentTermFrom)) {
      current.add(r);
    } else {
      previous.add(r);
    }
  }
  return CommitteeTermSplit(
    current: dedupeCommitteeByPosition(current),
    previous: previous,
    currentTermFrom: currentTermFrom,
  );
}

List<CommitteeMemberRow> currentCommitteeMembers(List<CommitteeMemberRow> rows) => splitCommitteeTerms(rows).current;

/// True when the member is on the living roster for the given calendar day.
bool isCommitteeMemberEffectiveOn(CommitteeMemberRow row, [String? onDate]) {
  if (!row.isActive) return false;
  final day = onDate ?? localIsoDate();
  final from = _slice10(row.termFrom);
  final to = _slice10(row.termTo);
  if (from != null && from.compareTo(day) > 0) return false;
  if (to != null && to.compareTo(day) < 0) return false;
  return true;
}

List<CommitteeMemberRow> filterEffectiveCommitteeMembers(List<CommitteeMemberRow> rows, [String? onDate]) =>
    rows.where((r) => isCommitteeMemberEffectiveOn(r, onDate)).toList();

/// Position presets offered in the committee form.
const List<String> committeePositionPresets = [
  'President',
  'Vice-President',
  'Secretary',
  'Treasurer',
  'Cultural Secretary',
  'Committee Member',
];

/// Hindi display for a preset position (stored value stays English like the web).
String positionLabel(String position, {bool hi = false}) {
  if (!hi) return position;
  return switch (position.trim().toLowerCase()) {
    'president' => 'अध्यक्ष',
    'vice-president' => 'उपाध्यक्ष',
    'secretary' => 'सचिव',
    'treasurer' => 'कोषाध्यक्ष',
    'cultural secretary' => 'सांस्कृतिक सचिव',
    'committee member' => 'समिति सदस्य',
    _ => position,
  };
}

/// Validation of the committee form (web `save` guards). Returns (en, hi) or null.
(String, String)? validateCommitteeForm({
  required String position,
  required String flatId,
  required String flatNumber,
  required String name,
  required String termFrom,
  required String termTo,
  required String selectionType,
}) {
  if (position.trim().isEmpty) return ('Position is required', 'पद आवश्यक है');
  if (flatId.isEmpty || flatNumber.trim().isEmpty) return ('Select a flat number', 'फ्लैट नंबर चुनें');
  if (name.trim().isEmpty) return ('Name for this post is required', 'इस पद के लिए नाम आवश्यक है');
  if (termFrom.isEmpty) return ('Tenure start date (From) is required', 'कार्यकाल आरंभ तिथि आवश्यक है');
  if (selectionType.isEmpty) return ('Select how the member was chosen', 'सदस्य का चयन कैसे हुआ, चुनें');
  if (termTo.isNotEmpty && termTo.compareTo(termFrom) < 0) {
    return ('Tenure end date must be on or after start date', 'कार्यकाल समाप्ति तिथि आरंभ तिथि के बाद होनी चाहिए');
  }
  return null;
}

/// `committee_members` payload built from the form (web `save` payload).
Map<String, dynamic> committeeMemberPayload({
  required String societyId,
  required String flatId,
  required String flatNumber,
  required String flatOwnerName,
  required String name,
  required String position,
  required String phone,
  required String gender,
  required String photo,
  required bool showRepresentative,
  required String repName,
  required String repPhone,
  required String repPhoto,
  required int sortOrder,
  required String termFrom,
  required String termTo,
  required String selectionType,
}) {
  final isRep = committeeIsRepresentative(name: name, flatOwnerName: flatOwnerName);
  final isFemale = gender == 'female';
  final showFemaleRep = isFemale && showRepresentative;
  String? orNull(String s) => s.trim().isEmpty ? null : s.trim();
  return {
    'society_id': societyId,
    'flat_id': flatId,
    'flat_number': flatNumber.trim(),
    'flat_owner_name': orNull(flatOwnerName),
    'name': name.trim(),
    'position': position.trim(),
    'phone': orNull(phone),
    'gender': gender.isEmpty ? null : gender,
    'photo': photo.isEmpty ? null : photo,
    'show_representative': isRep || showFemaleRep,
    'rep_name': showFemaleRep ? orNull(repName) : (isRep ? name.trim() : null),
    'rep_phone': showFemaleRep ? orNull(repPhone) : null,
    'rep_photo': showFemaleRep ? (repPhoto.isEmpty ? null : repPhoto) : null,
    'sort_order': sortOrder,
    'term_from': termFrom,
    'term_to': orNull(termTo),
    'selection_type': selectionType,
    'is_active': true,
  };
}

String _norm(String? s) => (s ?? '').trim().toLowerCase();

/// True when this household member appears on the published committee roster —
/// admin-only edits (web `isMemberOnCommitteeRoster`).
bool isMemberOnCommitteeRoster({
  String? id,
  String? name,
  String? phone,
  String? flatId,
  required List<CommitteeMemberRow> committeeRows,
}) {
  final n = _norm(name);
  final p = (phone ?? '').replaceAll(RegExp(r'\D'), '');
  final f = flatId ?? '';
  for (final row in committeeRows) {
    if (f.isNotEmpty && row.flatId != null && row.flatId == f && n.isNotEmpty && _norm(row.name) == n) return true;
    if (f.isNotEmpty && row.flatId != null && row.flatId == f && n.isNotEmpty && _norm(row.flatOwnerName) == n) {
      return true;
    }
    if (p.isNotEmpty && row.phone != null && row.phone!.replaceAll(RegExp(r'\D'), '') == p) return true;
    if (id != null && id.isNotEmpty && row.flatId == f) {
      final holder = _norm(row.name);
      final owner = _norm(row.flatOwnerName);
      if (holder == n || owner == n) return true;
    }
  }
  return false;
}

// ---------------------------------------------------------------------------
// Standard duties chart (web `committeeDuty.ts`)
// ---------------------------------------------------------------------------

const List<String> standardDutyPresets = [
  'Maintenance & Repairs',
  'Security & Gate',
  'Housekeeping',
  'Electrical',
  'Plumbing',
  'Garden & Landscaping',
  'Lift / Elevator',
  'Parking',
  'Accounts & Billing',
  'Event Coordination',
];

/// Hindi display for a preset duty (stored label stays English like the web).
String dutyPresetLabel(String label, {bool hi = false}) {
  if (!hi) return label;
  return switch (label) {
    'Maintenance & Repairs' => 'रखरखाव एवं मरम्मत',
    'Security & Gate' => 'सुरक्षा एवं गेट',
    'Housekeeping' => 'साफ़-सफ़ाई',
    'Electrical' => 'बिजली',
    'Plumbing' => 'प्लंबिंग',
    'Garden & Landscaping' => 'उद्यान एवं भू-दृश्य',
    'Lift / Elevator' => 'लिफ़्ट',
    'Parking' => 'पार्किंग',
    'Accounts & Billing' => 'लेखा एवं बिलिंग',
    'Event Coordination' => 'कार्यक्रम समन्वय',
    _ => label,
  };
}

class CommitteeDutiesChartRow {
  const CommitteeDutiesChartRow({
    required this.id,
    required this.societyId,
    required this.periodFrom,
    this.periodTo,
    this.isActive = true,
  });

  final String id;
  final String societyId;
  final String periodFrom;
  final String? periodTo;
  final bool isActive;

  factory CommitteeDutiesChartRow.fromJson(Map<String, dynamic> j) => CommitteeDutiesChartRow(
        id: '${j['id']}',
        societyId: '${j['society_id'] ?? ''}',
        periodFrom: (j['period_from'] ?? '').toString(),
        periodTo: j['period_to'] as String?,
        isActive: j['is_active'] != false,
      );
}

class CommitteeDutyRow {
  const CommitteeDutyRow({
    required this.id,
    required this.chartId,
    required this.dutyLabel,
    required this.supervisorNames,
    this.sortOrder = 0,
  });

  final String id;
  final String chartId;
  final String dutyLabel;
  final List<String> supervisorNames;
  final int sortOrder;

  factory CommitteeDutyRow.fromJson(Map<String, dynamic> j) {
    final so = j['sort_order'];
    final names = j['supervisor_names'];
    return CommitteeDutyRow(
      id: '${j['id']}',
      chartId: '${j['chart_id'] ?? ''}',
      dutyLabel: (j['duty_label'] ?? '').toString(),
      supervisorNames: names is List ? names.map((e) => '$e').toList() : const [],
      sortOrder: so is num ? so.toInt() : 0,
    );
  }
}

/// Editable duty row in the chart editor.
class DutyFormRow {
  DutyFormRow({this.id, this.dutyLabel = '', this.supervisorNames = '', this.sortOrder = 0});

  String? id;
  String dutyLabel;
  String supervisorNames;
  int sortOrder;
}

List<String> parseSupervisorNames(String input) =>
    input.split(RegExp(r'[,;]+')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

String formatSupervisorNames(List<String> names) => names.where((n) => n.isNotEmpty).join(', ');

/// `from → to` or `from → Ongoing` (web `dutiesPeriodLabel`).
String dutiesPeriodLabel({required String periodFrom, String? periodTo, bool hi = false}) {
  final from = periodFrom.length > 10 ? periodFrom.substring(0, 10) : periodFrom;
  final to = _slice10(periodTo);
  return to != null ? '$from → $to' : '$from → ${hi ? 'जारी' : 'Ongoing'}';
}

/// Validated rows for saving the duties chart; `(error en, error hi)` on failure.
({List<({String dutyLabel, List<String> supervisors, int sortOrder})> rows, (String, String)? error})
    validateDutyRows({required String periodFrom, required String periodTo, required List<DutyFormRow> forms}) {
  if (periodFrom.isEmpty) {
    return (rows: const [], error: ('Period start date (From) is required', 'अवधि आरंभ तिथि आवश्यक है'));
  }
  if (periodTo.isNotEmpty && periodTo.compareTo(periodFrom) < 0) {
    return (
      rows: const [],
      error: ('Period end date must be on or after start date', 'अवधि समाप्ति तिथि आरंभ तिथि के बाद होनी चाहिए'),
    );
  }
  final valid = <({String dutyLabel, List<String> supervisors, int sortOrder})>[];
  for (var i = 0; i < forms.length; i++) {
    final label = forms[i].dutyLabel.trim();
    if (label.isEmpty) continue;
    valid.add((dutyLabel: label, supervisors: parseSupervisorNames(forms[i].supervisorNames), sortOrder: i));
  }
  if (valid.isEmpty) {
    return (rows: const [], error: ('Add at least one duty with a label', 'कम-से-कम एक कर्तव्य नाम सहित जोड़ें'));
  }
  for (final r in valid) {
    if (r.supervisors.isEmpty) {
      return (
        rows: const [],
        error: ('Supervisor name is required for "${r.dutyLabel}"', '"${r.dutyLabel}" के लिए पर्यवेक्षक का नाम आवश्यक है'),
      );
    }
  }
  return (rows: valid, error: null);
}
