export type StaffAttendanceStatus =
  | 'present'
  | 'absent'
  | 'late'
  | 'half_day'
  | 'not_required'
  | 'not_marked';

export type SystemCheckStatus = 'ok' | 'problem' | 'not_working' | 'not_checked';

export type IncidentSeverity = 'low' | 'medium' | 'high';

export type IncidentCategory =
  | 'lift_fault'
  | 'water_problem'
  | 'maintenance'
  | 'resident_complaint'
  | 'breakage'
  | 'chaos'
  | 'abnormality'
  | 'cctv_issue'
  | 'power_issue'
  | 'other';

export type GuardDailyDuty = {
  id: string;
  society_id: string;
  guard_uuid: string;
  guard_id: string;
  guard_name: string;
  shift_id: string;
  duty_date: string;
  status: 'in_progress' | 'submitted';
  submitted_at: string | null;
  created_at: string;
  updated_at: string;
};

export type GuardDutyStaffAttendance = {
  id: string;
  duty_id: string;
  staff_role: string;
  staff_name: string | null;
  status: StaffAttendanceStatus;
  absence_reason: string | null;
  updated_at: string;
};

export type GuardDutySystemCheck = {
  id: string;
  duty_id: string;
  check_key: string;
  status: SystemCheckStatus;
  problem_preset: string | null;
  updated_at: string;
};

export type GuardDutyIncident = {
  id: string;
  duty_id: string;
  category: IncidentCategory;
  severity: IncidentSeverity;
  flat_number: string | null;
  problem_preset: string | null;
  photo_urls: string[];
  created_at: string;
};

export type GuardDutyBundle = {
  duty: GuardDailyDuty;
  staff: GuardDutyStaffAttendance[];
  checks: GuardDutySystemCheck[];
  incidents: GuardDutyIncident[];
};

export const STAFF_ROLES = [
  { key: 'gardener', icon: '🌿' },
  { key: 'sweeper', icon: '🧹' },
  { key: 'housekeeper', icon: '🪣' },
  { key: 'electrician', icon: '⚡' },
  { key: 'plumber', icon: '🔧' },
  { key: 'lift_operator', icon: '🛗' },
  { key: 'security_helper', icon: '👮' },
] as const;

export type StaffRoleKey = (typeof STAFF_ROLES)[number]['key'];

export const SYSTEM_CHECKS = [
  { key: 'lift', icon: '🛗' },
  { key: 'water', icon: '💧' },
  { key: 'cctv', icon: '📹' },
  { key: 'power', icon: '🔌' },
  { key: 'generator', icon: '⚙️' },
  { key: 'gate', icon: '🚧' },
  { key: 'intercom', icon: '📞' },
  { key: 'stp', icon: '♻️' },
  { key: 'fire_alarm', icon: '🔥' },
] as const;

export type SystemCheckKey = (typeof SYSTEM_CHECKS)[number]['key'];

export const INCIDENT_CATEGORIES = [
  { key: 'lift_fault', icon: '🛗' },
  { key: 'water_problem', icon: '💧' },
  { key: 'maintenance', icon: '🔧' },
  { key: 'resident_complaint', icon: '📢' },
  { key: 'breakage', icon: '💥' },
  { key: 'chaos', icon: '⚠️' },
  { key: 'abnormality', icon: '👁️' },
  { key: 'cctv_issue', icon: '📹' },
  { key: 'power_issue', icon: '⚡' },
  { key: 'other', icon: '📝' },
] as const;

export const ABSENCE_REASONS = [
  'sick',
  'leave',
  'not_informed',
  'holiday',
  'unknown',
] as const;

export const PROBLEM_PRESETS: Record<SystemCheckKey, string[]> = {
  lift: ['stuck', 'not_working', 'noise', 'door_issue'],
  water: ['no_supply', 'low_pressure', 'tank_empty', 'leakage', 'dirty_water'],
  cctv: ['camera_down', 'no_recording', 'blur_image', 'monitor_off'],
  power: ['outage', 'partial_cut', 'meter_issue'],
  generator: ['not_starting', 'low_diesel', 'auto_fail'],
  gate: ['not_closing', 'remote_fail', 'damage'],
  intercom: ['not_working', 'static_noise'],
  stp: ['not_running', 'overflow', 'bad_smell'],
  fire_alarm: ['not_working', 'false_alarm', 'battery_low'],
};

export const INCIDENT_PRESETS: Record<IncidentCategory, string[]> = {
  lift_fault: ['stuck_passengers', 'not_working', 'door_problem'],
  water_problem: ['no_water', 'leakage', 'tank_issue'],
  maintenance: ['repair_needed', 'work_in_progress', 'vendor_visit'],
  resident_complaint: ['noise', 'parking', 'cleanliness', 'security'],
  breakage: ['glass', 'pipe', 'equipment', 'furniture'],
  chaos: ['fight', 'crowd', 'unauthorized_entry'],
  abnormality: ['suspicious_person', 'stray_animal', 'unusual_smell'],
  cctv_issue: ['camera_down', 'recording_missing'],
  power_issue: ['outage', 'short_circuit'],
  other: ['general', 'follow_up_needed'],
};
