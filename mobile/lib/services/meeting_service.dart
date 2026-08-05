import '../core/config/env.dart';
import '../core/supabase/supabase_bootstrap.dart';
import '../models/meeting.dart';

class MeetingService {
  Future<List<SocietyMeeting>> fetchPublished(String societyId) async {
    if (!Env.isConfigured) return const [];

    final rows = await SupabaseBootstrap.client
        .from('meetings')
        .select('*')
        .eq('society_id', societyId)
        .eq('published', true)
        .order('meeting_at', ascending: false)
        .limit(50);

    return (rows as List)
        .map((r) => SocietyMeeting.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<List<MeetingAgendaItem>> fetchAgenda(String meetingId) async {
    if (!Env.isConfigured) return const [];
    final rows = await SupabaseBootstrap.client
        .from('meeting_agenda_items')
        .select('*')
        .eq('meeting_id', meetingId)
        .order('sort_order');
    return (rows as List)
        .map((r) => MeetingAgendaItem.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<List<MeetingSuggestion>> fetchSuggestions(String meetingId) async {
    if (!Env.isConfigured) return const [];
    final rows = await SupabaseBootstrap.client
        .from('meeting_suggestions')
        .select('*')
        .eq('meeting_id', meetingId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => MeetingSuggestion.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<void> addSuggestion({
    required String meetingId,
    required String authorName,
    String? flatNumber,
    String? memberId,
    required String text,
  }) async {
    if (!Env.isConfigured) return;
    await SupabaseBootstrap.client.from('meeting_suggestions').insert({
      'meeting_id': meetingId,
      'author_name': authorName,
      'flat_number': flatNumber,
      'member_id': memberId,
      'suggestion_text': text,
    });
  }

  Future<void> proposeAgendaItem({
    required String meetingId,
    required String title,
    required String proposedByName,
    String? proposedByFlat,
    String? memberId,
  }) async {
    if (!Env.isConfigured) return;
    await SupabaseBootstrap.client.from('meeting_agenda_items').insert({
      'meeting_id': meetingId,
      'title': title,
      'source': 'resident',
      'status': 'proposed',
      'proposed_by_name': proposedByName,
      'proposed_by_flat': proposedByFlat,
      'proposed_by_member_id': memberId,
      'sort_order': 999,
    });
  }
}
