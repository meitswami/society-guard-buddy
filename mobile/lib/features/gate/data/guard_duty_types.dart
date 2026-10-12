import '../../../core/format/formatters.dart';

/// Port of web `src/lib/guardDutyTypes.ts` (daily duty sheet: staff attendance,
/// building checks, incident reports).

/// `present` | `absent` | `late` | `half_day` | `not_required` | `not_marked`
typedef StaffAttendanceStatus = String;

/// `ok` | `problem` | `not_working` | `not_checked`
typedef SystemCheckStatus = String;

/// `low` | `medium` | `high`
typedef IncidentSeverity = String;

class GuardDailyDuty {
  const GuardDailyDuty({
    required this.id,
    required this.societyId,
    required this.guardUuid,
    required this.guardId,
    required this.guardName,
    required this.shiftId,
    required this.dutyDate,
    required this.status,
    this.submittedAt,
    this.createdAt = '',
    this.updatedAt = '',
  });

  final String id;
  final String societyId;
  final String guardUuid;
  final String guardId;
  final String guardName;
  final String shiftId;

  /// `yyyy-MM-dd`
  final String dutyDate;

  /// `in_progress` | `submitted`
  final String status;
  final String? submittedAt;
  final String createdAt;
  final String updatedAt;

  bool get isSubmitted => status == 'submitted';

  factory GuardDailyDuty.fromRow(Map<String, dynamic> r) => GuardDailyDuty(
        id: asString(r['id']),
        societyId: asString(r['society_id']),
        guardUuid: asString(r['guard_uuid']),
        guardId: asString(r['guard_id']),
        guardName: asString(r['guard_name']),
        shiftId: asString(r['shift_id']),
        dutyDate: asString(r['duty_date']),
        status: r['status']?.toString() ?? 'in_progress',
        submittedAt: r['submitted_at']?.toString(),
        createdAt: asString(r['created_at']),
        updatedAt: asString(r['updated_at']),
      );
}

class GuardDutyStaffAttendance {
  const GuardDutyStaffAttendance({
    required this.id,
    required this.dutyId,
    required this.staffRole,
    this.staffName,
    required this.status,
    this.absenceReason,
    this.updatedAt = '',
  });

  final String id;
  final String dutyId;
  final String staffRole;
  final String? staffName;
  final StaffAttendanceStatus status;
  final String? absenceReason;
  final String updatedAt;

  factory GuardDutyStaffAttendance.fromRow(Map<String, dynamic> r) => GuardDutyStaffAttendance(
        id: asString(r['id']),
        dutyId: asString(r['duty_id']),
        staffRole: asString(r['staff_role']),
        staffName: r['staff_name']?.toString(),
        status: r['status']?.toString() ?? 'not_marked',
        absenceReason: r['absence_reason']?.toString(),
        updatedAt: asString(r['updated_at']),
      );
}

class GuardDutySystemCheck {
  const GuardDutySystemCheck({
    required this.id,
    required this.dutyId,
    required this.checkKey,
    required this.status,
    this.problemPreset,
    this.updatedAt = '',
  });

  final String id;
  final String dutyId;
  final String checkKey;
  final SystemCheckStatus status;
  final String? problemPreset;
  final String updatedAt;

  factory GuardDutySystemCheck.fromRow(Map<String, dynamic> r) => GuardDutySystemCheck(
        id: asString(r['id']),
        dutyId: asString(r['duty_id']),
        checkKey: asString(r['check_key']),
        status: r['status']?.toString() ?? 'not_checked',
        problemPreset: r['problem_preset']?.toString(),
        updatedAt: asString(r['updated_at']),
      );
}

class GuardDutyIncident {
  const GuardDutyIncident({
    required this.id,
    required this.dutyId,
    required this.category,
    required this.severity,
    this.flatNumber,
    this.problemPreset,
    this.photoUrls = const [],
    this.createdAt = '',
  });

  final String id;
  final String dutyId;
  final String category;
  final IncidentSeverity severity;
  final String? flatNumber;
  final String? problemPreset;
  final List<String> photoUrls;
  final String createdAt;

  factory GuardDutyIncident.fromRow(Map<String, dynamic> r) {
    final photos = r['photo_urls'];
    return GuardDutyIncident(
      id: asString(r['id']),
      dutyId: asString(r['duty_id']),
      category: asString(r['category']),
      severity: r['severity']?.toString() ?? 'medium',
      flatNumber: r['flat_number']?.toString(),
      problemPreset: r['problem_preset']?.toString(),
      photoUrls: photos is List ? photos.map((e) => e.toString()).toList() : const [],
      createdAt: asString(r['created_at']),
    );
  }
}

class GuardDutyBundle {
  const GuardDutyBundle({required this.duty, required this.staff, required this.checks, required this.incidents});

  final GuardDailyDuty duty;
  final List<GuardDutyStaffAttendance> staff;
  final List<GuardDutySystemCheck> checks;
  final List<GuardDutyIncident> incidents;
}

/// Key + emoji for the duty sheet grids.
class DutyItem {
  const DutyItem(this.key, this.icon);

  final String key;
  final String icon;
}

const List<DutyItem> kStaffRoles = [
  DutyItem('gardener', '🌿'),
  DutyItem('sweeper', '🧹'),
  DutyItem('housekeeper', '🪣'),
  DutyItem('electrician', '⚡'),
  DutyItem('plumber', '🔧'),
  DutyItem('lift_operator', '🛗'),
  DutyItem('security_helper', '👮'),
];

const List<DutyItem> kSystemChecks = [
  DutyItem('lift', '🛗'),
  DutyItem('water', '💧'),
  DutyItem('cctv', '📹'),
  DutyItem('power', '🔌'),
  DutyItem('generator', '⚙️'),
  DutyItem('gate', '🚧'),
  DutyItem('intercom', '📞'),
  DutyItem('stp', '♻️'),
  DutyItem('fire_alarm', '🔥'),
];

const List<DutyItem> kIncidentCategories = [
  DutyItem('lift_fault', '🛗'),
  DutyItem('water_problem', '💧'),
  DutyItem('maintenance', '🔧'),
  DutyItem('resident_complaint', '📢'),
  DutyItem('breakage', '💥'),
  DutyItem('chaos', '⚠️'),
  DutyItem('abnormality', '👁️'),
  DutyItem('cctv_issue', '📹'),
  DutyItem('power_issue', '⚡'),
  DutyItem('other', '📝'),
];

const List<String> kAbsenceReasons = ['sick', 'leave', 'not_informed', 'holiday', 'unknown'];

const Map<String, List<String>> kProblemPresets = {
  'lift': ['stuck', 'not_working', 'noise', 'door_issue'],
  'water': ['no_supply', 'low_pressure', 'tank_empty', 'leakage', 'dirty_water'],
  'cctv': ['camera_down', 'no_recording', 'blur_image', 'monitor_off'],
  'power': ['outage', 'partial_cut', 'meter_issue'],
  'generator': ['not_starting', 'low_diesel', 'auto_fail'],
  'gate': ['not_closing', 'remote_fail', 'damage'],
  'intercom': ['not_working', 'static_noise'],
  'stp': ['not_running', 'overflow', 'bad_smell'],
  'fire_alarm': ['not_working', 'false_alarm', 'battery_low'],
};

const Map<String, List<String>> kIncidentPresets = {
  'lift_fault': ['stuck_passengers', 'not_working', 'door_problem'],
  'water_problem': ['no_water', 'leakage', 'tank_issue'],
  'maintenance': ['repair_needed', 'work_in_progress', 'vendor_visit'],
  'resident_complaint': ['noise', 'parking', 'cleanliness', 'security'],
  'breakage': ['glass', 'pipe', 'equipment', 'furniture'],
  'chaos': ['fight', 'crowd', 'unauthorized_entry'],
  'abnormality': ['suspicious_person', 'stray_animal', 'unusual_smell'],
  'cctv_issue': ['camera_down', 'recording_missing'],
  'power_issue': ['outage', 'short_circuit'],
  'other': ['general', 'follow_up_needed'],
};

/// Staff attendance buttons (status, emoji, colour variant).
const List<({String status, String icon, DutyTone tone})> kAttendanceOptions = [
  (status: 'present', icon: '✅', tone: DutyTone.success),
  (status: 'absent', icon: '❌', tone: DutyTone.danger),
  (status: 'late', icon: '⏰', tone: DutyTone.warning),
  (status: 'not_required', icon: '➖', tone: DutyTone.muted),
];

/// Building check status buttons.
const List<({String status, String icon, DutyTone tone})> kCheckStatusOptions = [
  (status: 'ok', icon: '✅', tone: DutyTone.success),
  (status: 'problem', icon: '⚠️', tone: DutyTone.warning),
  (status: 'not_working', icon: '🚫', tone: DutyTone.danger),
];

/// Incident severity buttons.
const List<({String severity, String icon, DutyTone tone})> kSeverityOptions = [
  (severity: 'low', icon: '🟢', tone: DutyTone.success),
  (severity: 'medium', icon: '🟡', tone: DutyTone.warning),
  (severity: 'high', icon: '🔴', tone: DutyTone.danger),
];

/// Colour family of a duty tap button / status box (web `BigTapButton` variants).
enum DutyTone { success, warning, danger, muted, primary, none }

/// Web `statusColor`: tint of the staff row / check tile for a status.
DutyTone dutyStatusTone(String status) {
  if (status == 'present' || status == 'ok') return DutyTone.success;
  if (status == 'absent' || status == 'not_working') return DutyTone.danger;
  if (status == 'late' || status == 'problem') return DutyTone.warning;
  return DutyTone.none;
}

/// Absent / late need a reason first (web opens the reason dialog).
bool attendanceNeedsReason(String status) => status == 'absent' || status == 'late';

/// Reason saved with an attendance row (cleared unless absent / late).
String? attendanceReasonToSave(String status, String? reason) => attendanceNeedsReason(status) ? reason : null;

/// Problem preset saved with a check (cleared for `ok` / `not_checked`).
String? checkPresetToSave(String status, String? preset) => (status == 'ok' || status == 'not_checked') ? null : preset;

/// Problem presets are offered for `problem` / `not_working`.
bool checkNeedsPreset(String status) => status == 'problem' || status == 'not_working';

String findIcon(List<DutyItem> items, String key) {
  for (final i in items) {
    if (i.key == key) return i.icon;
  }
  return '';
}

GuardDutyStaffAttendance? staffRowFor(GuardDutyBundle b, String role) {
  for (final s in b.staff) {
    if (s.staffRole == role) return s;
  }
  return null;
}

GuardDutySystemCheck? checkRowFor(GuardDutyBundle b, String key) {
  for (final c in b.checks) {
    if (c.checkKey == key) return c;
  }
  return null;
}

/// Checks reported as `problem` / `not_working` (admin review "issues").
List<GuardDutySystemCheck> dutyProblemChecks(GuardDutyBundle b) =>
    b.checks.where((c) => c.status == 'problem' || c.status == 'not_working').toList();

/// Staff marked absent / late (admin review).
List<GuardDutyStaffAttendance> dutyAbsentStaff(GuardDutyBundle b) =>
    b.staff.where((s) => s.status == 'absent' || s.status == 'late').toList();

/// Seed rows inserted with a new duty sheet.
List<Map<String, dynamic>> staffSeedRows(String dutyId) =>
    [for (final r in kStaffRoles) {'duty_id': dutyId, 'staff_role': r.key, 'status': 'not_marked'}];

List<Map<String, dynamic>> checkSeedRows(String dutyId) =>
    [for (final c in kSystemChecks) {'duty_id': dutyId, 'check_key': c.key, 'status': 'not_checked'}];

/// `yyyy-MM-dd` → local date (avoids the UTC shift of `new Date('yyyy-MM-dd')`).
DateTime? parseDutyDate(String iso) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(iso);
  if (m == null) return null;
  return DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
}
