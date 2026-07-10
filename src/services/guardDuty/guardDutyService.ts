import { supabase } from '@/integrations/supabase/client';
import { format } from 'date-fns';
import type {
  GuardDutyBundle,
  GuardDutyIncident,
  GuardDutyStaffAttendance,
  GuardDutySystemCheck,
  GuardDailyDuty,
  IncidentCategory,
  IncidentSeverity,
  StaffAttendanceStatus,
  SystemCheckStatus,
} from '@/lib/guardDutyTypes';
import { STAFF_ROLES, SYSTEM_CHECKS } from '@/lib/guardDutyTypes';

function mapDuty(row: Record<string, unknown>): GuardDailyDuty {
  return row as unknown as GuardDailyDuty;
}

function mapStaff(row: Record<string, unknown>): GuardDutyStaffAttendance {
  return row as unknown as GuardDutyStaffAttendance;
}

function mapCheck(row: Record<string, unknown>): GuardDutySystemCheck {
  return row as unknown as GuardDutySystemCheck;
}

function mapIncident(row: Record<string, unknown>): GuardDutyIncident {
  const r = row as Record<string, unknown>;
  return {
    ...(r as unknown as GuardDutyIncident),
    photo_urls: Array.isArray(r.photo_urls) ? (r.photo_urls as string[]) : [],
  };
}

export async function resolveGuardUuid(guardId: string, societyId: string): Promise<string | null> {
  const { data } = await supabase
    .from('guards')
    .select('id')
    .eq('guard_id', guardId)
    .eq('society_id', societyId)
    .maybeSingle();
  return data?.id ?? null;
}

async function fetchDutyChildren(dutyId: string): Promise<Pick<GuardDutyBundle, 'staff' | 'checks' | 'incidents'>> {
  const [staffRes, checksRes, incidentsRes] = await Promise.all([
    supabase.from('guard_duty_staff_attendance').select('*').eq('duty_id', dutyId),
    supabase.from('guard_duty_system_checks').select('*').eq('duty_id', dutyId),
    supabase.from('guard_duty_incidents').select('*').eq('duty_id', dutyId).order('created_at', { ascending: false }),
  ]);

  if (staffRes.error) throw staffRes.error;
  if (checksRes.error) throw checksRes.error;
  if (incidentsRes.error) throw incidentsRes.error;

  return {
    staff: (staffRes.data ?? []).map(mapStaff),
    checks: (checksRes.data ?? []).map(mapCheck),
    incidents: (incidentsRes.data ?? []).map(mapIncident),
  };
}

export async function getOrCreateDutyForShift(params: {
  societyId: string;
  shiftId: string;
  guardUuid: string;
  guardId: string;
  guardName: string;
}): Promise<GuardDutyBundle> {
  const dutyDate = format(new Date(), 'yyyy-MM-dd');

  const { data: existing, error: findErr } = await supabase
    .from('guard_daily_duty')
    .select('*')
    .eq('shift_id', params.shiftId)
    .maybeSingle();

  if (findErr) throw findErr;

  let duty: GuardDailyDuty;
  if (existing) {
    duty = mapDuty(existing);
  } else {
    const { data: created, error: createErr } = await supabase
      .from('guard_daily_duty')
      .insert({
        society_id: params.societyId,
        guard_uuid: params.guardUuid,
        guard_id: params.guardId,
        guard_name: params.guardName,
        shift_id: params.shiftId,
        duty_date: dutyDate,
      })
      .select('*')
      .single();

    if (createErr) throw createErr;
    duty = mapDuty(created);

    const staffSeed = STAFF_ROLES.map((r) => ({
      duty_id: duty.id,
      staff_role: r.key,
      status: 'not_marked' as const,
    }));
    const checkSeed = SYSTEM_CHECKS.map((c) => ({
      duty_id: duty.id,
      check_key: c.key,
      status: 'not_checked' as const,
    }));

    const [staffIns, checkIns] = await Promise.all([
      supabase.from('guard_duty_staff_attendance').insert(staffSeed),
      supabase.from('guard_duty_system_checks').insert(checkSeed),
    ]);
    if (staffIns.error) throw staffIns.error;
    if (checkIns.error) throw checkIns.error;
  }

  const children = await fetchDutyChildren(duty.id);
  return { duty, ...children };
}

export async function updateStaffAttendance(
  dutyId: string,
  staffRole: string,
  status: StaffAttendanceStatus,
  absenceReason?: string | null,
): Promise<void> {
  const { error } = await supabase
    .from('guard_duty_staff_attendance')
    .update({
      status,
      absence_reason: status === 'absent' || status === 'late' ? absenceReason ?? null : null,
      updated_at: new Date().toISOString(),
    })
    .eq('duty_id', dutyId)
    .eq('staff_role', staffRole);

  if (error) throw error;
}

export async function updateSystemCheck(
  dutyId: string,
  checkKey: string,
  status: SystemCheckStatus,
  problemPreset?: string | null,
): Promise<void> {
  const { error } = await supabase
    .from('guard_duty_system_checks')
    .update({
      status,
      problem_preset: status === 'ok' || status === 'not_checked' ? null : problemPreset ?? null,
      updated_at: new Date().toISOString(),
    })
    .eq('duty_id', dutyId)
    .eq('check_key', checkKey);

  if (error) throw error;
}

export async function addIncident(
  dutyId: string,
  input: {
    category: IncidentCategory;
    severity: IncidentSeverity;
    flatNumber?: string | null;
    problemPreset?: string | null;
    photoUrls?: string[];
  },
): Promise<GuardDutyIncident> {
  const { data, error } = await supabase
    .from('guard_duty_incidents')
    .insert({
      duty_id: dutyId,
      category: input.category,
      severity: input.severity,
      flat_number: input.flatNumber?.trim() || null,
      problem_preset: input.problemPreset ?? null,
      photo_urls: input.photoUrls ?? [],
    })
    .select('*')
    .single();

  if (error) throw error;
  return mapIncident(data);
}

export async function submitDuty(dutyId: string): Promise<void> {
  const { error } = await supabase
    .from('guard_daily_duty')
    .update({
      status: 'submitted',
      submitted_at: new Date().toISOString(),
    })
    .eq('id', dutyId);

  if (error) throw error;
}

export async function fetchDutyHistory(societyId: string, limit = 30): Promise<GuardDutyBundle[]> {
  const { data: duties, error } = await supabase
    .from('guard_daily_duty')
    .select('*')
    .eq('society_id', societyId)
    .order('duty_date', { ascending: false })
    .limit(limit);

  if (error) throw error;
  if (!duties?.length) return [];

  const bundles: GuardDutyBundle[] = [];
  for (const row of duties) {
    const duty = mapDuty(row);
    const children = await fetchDutyChildren(duty.id);
    bundles.push({ duty, ...children });
  }
  return bundles;
}

export async function fetchDutyById(dutyId: string): Promise<GuardDutyBundle | null> {
  const { data, error } = await supabase
    .from('guard_daily_duty')
    .select('*')
    .eq('id', dutyId)
    .maybeSingle();

  if (error) throw error;
  if (!data) return null;

  const duty = mapDuty(data);
  const children = await fetchDutyChildren(duty.id);
  return { duty, ...children };
}
