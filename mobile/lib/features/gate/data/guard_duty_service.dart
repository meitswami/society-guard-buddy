import '../../../core/format/formatters.dart';
import '../../../core/supabase/db.dart';
import 'guard_duty_types.dart';

/// Port of web `src/services/guardDuty/guardDutyService.ts` (same tables, filters, writes).
class GuardDutyService {
  const GuardDutyService();

  /// `guards.id` for a guard code in the society.
  Future<String?> resolveGuardUuid(String guardId, String societyId) async {
    if (!dbReady) return null;
    final row = await db
        .from('guards')
        .select('id')
        .eq('guard_id', guardId)
        .eq('society_id', societyId)
        .maybeSingle();
    return row?['id'] as String?;
  }

  Future<
      ({
        List<GuardDutyStaffAttendance> staff,
        List<GuardDutySystemCheck> checks,
        List<GuardDutyIncident> incidents
      })> _fetchChildren(String dutyId) async {
    final results = await Future.wait([
      db.from('guard_duty_staff_attendance').select('*').eq('duty_id', dutyId),
      db.from('guard_duty_system_checks').select('*').eq('duty_id', dutyId),
      db
          .from('guard_duty_incidents')
          .select('*')
          .eq('duty_id', dutyId)
          .order('created_at', ascending: false),
    ]);
    return (
      staff: rowsOf(results[0]).map(GuardDutyStaffAttendance.fromRow).toList(),
      checks: rowsOf(results[1]).map(GuardDutySystemCheck.fromRow).toList(),
      incidents: rowsOf(results[2]).map(GuardDutyIncident.fromRow).toList(),
    );
  }

  /// One duty sheet per guard shift; created (with seed rows) the first time it is opened.
  Future<GuardDutyBundle> getOrCreateDutyForShift({
    required String societyId,
    required String shiftId,
    required String guardUuid,
    required String guardId,
    required String guardName,
  }) async {
    final existing = await db
        .from('guard_daily_duty')
        .select('*')
        .eq('shift_id', shiftId)
        .maybeSingle();

    GuardDailyDuty duty;
    if (existing != null) {
      duty = GuardDailyDuty.fromRow(existing);
    } else {
      final created = await db
          .from('guard_daily_duty')
          .insert({
            'society_id': societyId,
            'guard_uuid': guardUuid,
            'guard_id': guardId,
            'guard_name': guardName,
            'shift_id': shiftId,
            'duty_date': Fmt.todayIso(),
          })
          .select('*')
          .single();
      duty = GuardDailyDuty.fromRow(created);
      await Future.wait([
        db.from('guard_duty_staff_attendance').insert(staffSeedRows(duty.id)),
        db.from('guard_duty_system_checks').insert(checkSeedRows(duty.id)),
      ]);
    }

    final c = await _fetchChildren(duty.id);
    return GuardDutyBundle(
        duty: duty, staff: c.staff, checks: c.checks, incidents: c.incidents);
  }

  Future<void> updateStaffAttendance(
      String dutyId, String staffRole, String status,
      {String? absenceReason}) async {
    await db
        .from('guard_duty_staff_attendance')
        .update({
          'status': status,
          'absence_reason': attendanceReasonToSave(status, absenceReason),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('duty_id', dutyId)
        .eq('staff_role', staffRole);
  }

  Future<void> updateSystemCheck(String dutyId, String checkKey, String status,
      {String? problemPreset}) async {
    await db
        .from('guard_duty_system_checks')
        .update({
          'status': status,
          'problem_preset': checkPresetToSave(status, problemPreset),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('duty_id', dutyId)
        .eq('check_key', checkKey);
  }

  Future<GuardDutyIncident> addIncident(
    String dutyId, {
    required String category,
    required String severity,
    String? flatNumber,
    String? problemPreset,
    List<String> photoUrls = const [],
  }) async {
    final flat = flatNumber?.trim() ?? '';
    final row = await db
        .from('guard_duty_incidents')
        .insert({
          'duty_id': dutyId,
          'category': category,
          'severity': severity,
          'flat_number': flat.isEmpty ? null : flat,
          'problem_preset': problemPreset,
          'photo_urls': photoUrls,
        })
        .select('*')
        .single();
    return GuardDutyIncident.fromRow(row);
  }

  Future<void> submitDuty(String dutyId) async {
    await db.from('guard_daily_duty').update({
      'status': 'submitted',
      'submitted_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', dutyId);
  }

  /// Latest [limit] duty sheets of the society with their rows (admin review).
  /// Children are fetched in three batched queries instead of three per sheet.
  Future<List<GuardDutyBundle>> fetchDutyHistory(String societyId,
      {int limit = 30}) async {
    if (!dbReady) return const [];
    final duties = rowsOf(
      await db
          .from('guard_daily_duty')
          .select('*')
          .eq('society_id', societyId)
          .order('duty_date', ascending: false)
          .limit(limit),
    ).map(GuardDailyDuty.fromRow).toList();
    if (duties.isEmpty) return const [];

    final ids = duties.map((d) => d.id).toList();
    final results = await Future.wait([
      db
          .from('guard_duty_staff_attendance')
          .select('*')
          .inFilter('duty_id', ids),
      db.from('guard_duty_system_checks').select('*').inFilter('duty_id', ids),
      db
          .from('guard_duty_incidents')
          .select('*')
          .inFilter('duty_id', ids)
          .order('created_at', ascending: false),
    ]);
    final staff =
        rowsOf(results[0]).map(GuardDutyStaffAttendance.fromRow).toList();
    final checks =
        rowsOf(results[1]).map(GuardDutySystemCheck.fromRow).toList();
    final incidents =
        rowsOf(results[2]).map(GuardDutyIncident.fromRow).toList();

    return [
      for (final d in duties)
        GuardDutyBundle(
          duty: d,
          staff: staff.where((s) => s.dutyId == d.id).toList(),
          checks: checks.where((c) => c.dutyId == d.id).toList(),
          incidents: incidents.where((i) => i.dutyId == d.id).toList(),
        ),
    ];
  }

  Future<GuardDutyBundle?> fetchDutyById(String dutyId) async {
    final row = await db
        .from('guard_daily_duty')
        .select('*')
        .eq('id', dutyId)
        .maybeSingle();
    if (row == null) return null;
    final duty = GuardDailyDuty.fromRow(row);
    final c = await _fetchChildren(duty.id);
    return GuardDutyBundle(
        duty: duty, staff: c.staff, checks: c.checks, incidents: c.incidents);
  }
}
