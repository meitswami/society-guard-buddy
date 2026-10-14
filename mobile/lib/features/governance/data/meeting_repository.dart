import 'dart:typed_data';

import '../../../core/supabase/db.dart';
import '../logic/meeting_logic.dart';
import '../models/meeting_models.dart';
import 'gov_backend.dart';

/// Supabase access for meetings — queries identical to web `MeetingManager.tsx`.
class MeetingRepository {
  const MeetingRepository(this.societyId);

  final String societyId;

  Future<List<MeetingRow>> loadMeetings({required bool residentOnly}) async {
    if (!dbReady) return const [];
    var q = db.from('meetings').select('*').eq('society_id', societyId);
    if (residentOnly) q = q.eq('published', true);
    final rows = rowsOf(await q.order('meeting_at', ascending: false));
    return rows.map(MeetingRow.fromJson).toList();
  }

  Future<MeetingRow?> loadMeeting(String id) async {
    if (!dbReady) return null;
    final row =
        await db.from('meetings').select('*').eq('id', id).maybeSingle();
    return row == null ? null : MeetingRow.fromJson(row);
  }

  /// Members of the society for the attendance pickers (web `loadMembers`).
  Future<List<MemberPick>> loadMembers() async {
    if (!dbReady) return const [];
    final flats = rowsOf(await db
        .from('flats')
        .select('id, flat_number')
        .eq('society_id', societyId));
    if (flats.isEmpty) return const [];
    final flatNum = {
      for (final f in flats) '${f['id']}': (f['flat_number'] ?? '').toString()
    };
    final mems = rowsOf(
      await db
          .from('members')
          .select('id, name, flat_id')
          .inFilter('flat_id', flatNum.keys.toList()),
    );
    return mems
        .map((m) => MemberPick(
              id: '${m['id']}',
              name: (m['name'] ?? '').toString(),
              flatId: '${m['flat_id']}',
              flatNumber: flatNum['${m['flat_id']}'] ?? '',
              photo: m['photo'] is String ? m['photo'] as String : null,
            ))
        .toList();
  }

  /// Flats with their members for the "mark flat present" grid (web `loadFlatsWithMembers`).
  Future<List<FlatWithMembers>> loadFlatsWithMembers() async {
    if (!dbReady) return const [];
    final flats = rowsOf(
      await db
          .from('flats')
          .select('id, flat_number, owner_name')
          .eq('society_id', societyId)
          .order('flat_number', ascending: true),
    );
    if (flats.isEmpty) return const [];
    final ids = flats.map((f) => '${f['id']}').toList();
    final mems = rowsOf(await db
        .from('members')
        .select('id, name, flat_id')
        .inFilter('flat_id', ids));
    final byFlat = <String, List<({String id, String name})>>{};
    for (final m in mems) {
      byFlat
          .putIfAbsent('${m['flat_id']}', () => [])
          .add((id: '${m['id']}', name: (m['name'] ?? '').toString()));
    }
    return flats
        .map((f) => FlatWithMembers(
              id: '${f['id']}',
              flatNumber: (f['flat_number'] ?? '').toString(),
              ownerName: f['owner_name'] as String?,
              members: byFlat['${f['id']}'] ?? const [],
            ))
        .toList();
  }

  /// Web `loadDetail`.
  Future<MeetingDetail> loadDetail(String meetingId) async {
    if (!dbReady) return const MeetingDetail();
    final results = await Future.wait([
      db
          .from('meeting_attendees')
          .select('*')
          .eq('meeting_id', meetingId)
          .order('display_name', ascending: true),
      db
          .from('meeting_decisions')
          .select('*')
          .eq('meeting_id', meetingId)
          .order('sort_order', ascending: true),
      db
          .from('meeting_documents')
          .select('*')
          .eq('meeting_id', meetingId)
          .order('sort_order', ascending: true)
          .order('created_at', ascending: true),
      db
          .from('meeting_agenda_items')
          .select('*')
          .eq('meeting_id', meetingId)
          .order('sort_order', ascending: true),
      db
          .from('meeting_suggestions')
          .select('*')
          .eq('meeting_id', meetingId)
          .order('created_at', ascending: false),
    ]);
    final docs = rowsOf(results[2]).map(MeetingDocRow.fromJson).toList();
    var sigs = const <SignatureRow>[];
    if (docs.isNotEmpty) {
      sigs = rowsOf(
        await db
            .from('meeting_document_signatures')
            .select('*')
            .inFilter('meeting_document_id', docs.map((d) => d.id).toList()),
      ).map(SignatureRow.fromJson).toList();
    }
    return MeetingDetail(
      attendees: rowsOf(results[0]).map(AttendeeRow.fromJson).toList(),
      decisions: rowsOf(results[1]).map(DecisionRow.fromJson).toList(),
      documents: docs,
      signatures: sigs,
      agendaItems: rowsOf(results[3]).map(AgendaItemRow.fromJson).toList(),
      suggestions: rowsOf(results[4]).map(SuggestionRow.fromJson).toList(),
    );
  }

  Future<void> patchMeeting(String id, Map<String, dynamic> patch) =>
      db.from('meetings').update(patch).eq('id', id);

  Future<MeetingRow> createMeeting({
    required String title,
    required String description,
    required MeetingKind kind,
    required String location,
    required String meetingAt,
    required bool published,
    required String createdBy,
  }) async {
    final row = await db
        .from('meetings')
        .insert({
          'society_id': societyId,
          'title': title,
          'description': description,
          'meeting_kind': kind.value,
          'location': location,
          'meeting_at': meetingAt,
          'status': 'scheduled',
          'published': published,
          'created_by': createdBy,
        })
        .select()
        .single();
    return MeetingRow.fromJson(row);
  }

  Future<void> deleteMeeting(String id) =>
      db.from('meetings').delete().eq('id', id);

  // --- agenda -------------------------------------------------------------

  Future<void> insertAgendaItems(List<Map<String, dynamic>> rows) =>
      db.from('meeting_agenda_items').insert(rows);

  Future<void> setAgendaStatus(String id, String status) =>
      db.from('meeting_agenda_items').update({'status': status}).eq('id', id);

  Future<void> deleteAgendaItem(String id) =>
      db.from('meeting_agenda_items').delete().eq('id', id);

  Future<void> addSuggestion(Map<String, dynamic> row) =>
      db.from('meeting_suggestions').insert(row);

  // --- attendance ---------------------------------------------------------

  Future<void> insertAttendees(List<Map<String, dynamic>> rows) =>
      db.from('meeting_attendees').insert(rows);

  Future<void> updateAttendee(String id, Map<String, dynamic> patch) =>
      db.from('meeting_attendees').update(patch).eq('id', id);

  Future<void> deleteAttendee(String id) =>
      db.from('meeting_attendees').delete().eq('id', id);

  // --- decisions ----------------------------------------------------------

  Future<void> addDecision(String meetingId, int sortOrder) =>
      db.from('meeting_decisions').insert({
        'meeting_id': meetingId,
        'decision_text': 'New decision — edit below (auto-saves)',
        'sort_order': sortOrder,
      });

  Future<void> updateDecision(String id, String text) =>
      db.from('meeting_decisions').update({'decision_text': text}).eq('id', id);

  Future<void> deleteDecision(String id) =>
      db.from('meeting_decisions').delete().eq('id', id);

  // --- documents ----------------------------------------------------------

  Future<void> insertDocument(Map<String, dynamic> row) =>
      db.from('meeting_documents').insert(row);

  Future<void> setDocumentOrder(String id, int order) =>
      db.from('meeting_documents').update({'sort_order': order}).eq('id', id);

  Future<String?> upload({
    required String meetingId,
    required String kind,
    required Uint8List bytes,
    required String fileName,
    String? contentType,
  }) =>
      GovBackend.uploadMeetingFile(
        societyId: societyId,
        meetingId: meetingId,
        kind: kind,
        bytes: bytes,
        fileName: fileName,
        contentType: contentType,
      );

  // --- signatures ---------------------------------------------------------

  Future<void> updateSignature(String id, Map<String, dynamic> patch) =>
      db.from('meeting_document_signatures').update(patch).eq('id', id);

  Future<void> insertSignature(Map<String, dynamic> row) =>
      db.from('meeting_document_signatures').insert(row);
}
