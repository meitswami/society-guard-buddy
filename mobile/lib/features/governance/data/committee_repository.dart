import '../../../core/supabase/db.dart';
import '../logic/committee_logic.dart';

/// Flat option in the committee form (web `FlatOption`).
class CommitteeFlatOption {
  const CommitteeFlatOption({
    required this.id,
    required this.flatNumber,
    this.ownerName,
    required this.primaryMemberName,
    this.primaryMemberPhoto,
  });

  final String id;
  final String flatNumber;
  final String? ownerName;
  final String primaryMemberName;
  final String? primaryMemberPhoto;
}

/// Supabase access for the committee roster and duties chart (web `CommitteeManager.tsx`,
/// `CommitteeDutiesChart.tsx`).
class CommitteeRepository {
  const CommitteeRepository(this.societyId);

  final String societyId;

  /// Active roster ordered by sort_order, name; photos refreshed from the live household
  /// member with the same flat + name (web `load`).
  Future<List<CommitteeMemberRow>> loadRoster() async {
    if (!dbReady) return const [];
    final roster = rowsOf(
      await db
          .from('committee_members')
          .select('*')
          .eq('society_id', societyId)
          .eq('is_active', true)
          .order('sort_order', ascending: true)
          .order('name', ascending: true),
    ).map(CommitteeMemberRow.fromJson).toList();

    final flatIds = roster.map((r) => r.flatId).whereType<String>().where((s) => s.isNotEmpty).toSet().toList();
    if (flatIds.isNotEmpty) {
      final mems = rowsOf(await db.from('members').select('flat_id, name, photo').inFilter('flat_id', flatIds));
      final live = <String, String>{};
      for (final m in mems) {
        final photo = m['photo'] is String ? (m['photo'] as String).trim() : '';
        final name = m['name'] is String ? (m['name'] as String).trim() : '';
        if (m['flat_id'] != null && name.isNotEmpty && photo.isNotEmpty) live['${m['flat_id']}|$name'] = photo;
      }
      for (final row in roster) {
        if (row.flatId == null || row.name.isEmpty) continue;
        final hit = live['${row.flatId}|${row.name.trim()}'];
        if (hit != null) row.photo = hit;
      }
    }
    return roster;
  }

  /// Flats with their primary member (web `loadFlats`).
  Future<List<CommitteeFlatOption>> loadFlats() async {
    if (!dbReady) return const [];
    final flats = rowsOf(
      await db.from('flats').select('id, flat_number, owner_name').eq('society_id', societyId).order('flat_number'),
    );
    final ids = flats.map((f) => '${f['id']}').toList();
    final primaries = ids.isEmpty
        ? const <Map<String, dynamic>>[]
        : rowsOf(await db.from('members').select('flat_id, name, photo').eq('is_primary', true).inFilter('flat_id', ids));
    final byFlat = <String, ({String name, String? photo})>{};
    for (final p in primaries) {
      final name = (p['name'] ?? '').toString().trim();
      if (p['flat_id'] != null && name.isNotEmpty) {
        final photo = p['photo'] is String && (p['photo'] as String).trim().isNotEmpty ? (p['photo'] as String).trim() : null;
        byFlat['${p['flat_id']}'] = (name: name, photo: photo);
      }
    }
    return flats.map((f) {
      final primary = byFlat['${f['id']}'];
      final owner = f['owner_name'] as String?;
      return CommitteeFlatOption(
        id: '${f['id']}',
        flatNumber: (f['flat_number'] ?? '').toString(),
        ownerName: owner,
        primaryMemberName: primary?.name ?? owner?.trim() ?? '',
        primaryMemberPhoto: primary?.photo,
      );
    }).toList();
  }

  Future<void> insertMember(Map<String, dynamic> payload) => db.from('committee_members').insert(payload);

  Future<void> updateMember(String id, Map<String, dynamic> payload) =>
      db.from('committee_members').update(payload).eq('id', id);

  /// Soft remove (`is_active = false`).
  Future<void> removeMember(String id) => db.from('committee_members').update({'is_active': false}).eq('id', id);

  // --- duties chart -------------------------------------------------------

  Future<({CommitteeDutiesChartRow? chart, List<CommitteeDutyRow> rows})> loadDuties() async {
    if (!dbReady) return (chart: null, rows: const <CommitteeDutyRow>[]);
    final chartData = await db
        .from('committee_duties_charts')
        .select('*')
        .eq('society_id', societyId)
        .eq('is_active', true)
        .maybeSingle();
    if (chartData == null) return (chart: null, rows: const <CommitteeDutyRow>[]);
    final chart = CommitteeDutiesChartRow.fromJson(chartData);
    final rows = rowsOf(
      await db
          .from('committee_duty_rows')
          .select('*')
          .eq('chart_id', chart.id)
          .order('sort_order', ascending: true)
          .order('duty_label', ascending: true),
    ).map(CommitteeDutyRow.fromJson).toList();
    return (chart: chart, rows: rows);
  }

  /// Web `save`: update (and replace rows) or create a new active chart.
  Future<void> saveDuties({
    required String? chartId,
    required String periodFrom,
    required String periodTo,
    required List<({String dutyLabel, List<String> supervisors, int sortOrder})> rows,
  }) async {
    var id = chartId;
    final to = periodTo.trim().isEmpty ? null : periodTo.trim();
    if (id != null) {
      await db.from('committee_duties_charts').update({'period_from': periodFrom, 'period_to': to}).eq('id', id);
      await db.from('committee_duty_rows').delete().eq('chart_id', id);
    } else {
      final inserted = await db
          .from('committee_duties_charts')
          .insert({'society_id': societyId, 'period_from': periodFrom, 'period_to': to, 'is_active': true})
          .select('id')
          .single();
      id = '${inserted['id']}';
    }
    await db.from('committee_duty_rows').insert([
      for (final r in rows)
        {'chart_id': id, 'duty_label': r.dutyLabel, 'supervisor_names': r.supervisors, 'sort_order': r.sortOrder},
    ]);
  }

  Future<void> removeDutiesChart(String chartId) =>
      db.from('committee_duties_charts').update({'is_active': false}).eq('id', chartId);
}
