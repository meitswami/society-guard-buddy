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
}
