import '../core/config/env.dart';
import '../core/supabase/supabase_bootstrap.dart';
import '../models/poll_models.dart';

class PollBundle {
  const PollBundle({
    required this.polls,
    required this.options,
    required this.votes,
  });

  final List<SocietyPoll> polls;
  final List<PollOption> options;
  final List<Map<String, dynamic>> votes;
}

class PollService {
  Future<PollBundle> fetchForSociety(String societyId) async {
    if (!Env.isConfigured) {
      return const PollBundle(polls: [], options: [], votes: []);
    }

    final pollRows = await SupabaseBootstrap.client
        .from('polls')
        .select('*')
        .eq('society_id', societyId)
        .order('created_at', ascending: false);

    final polls = (pollRows as List)
        .map((r) => SocietyPoll.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();

    if (polls.isEmpty) {
      return const PollBundle(polls: [], options: [], votes: []);
    }

    final pollIds = polls.map((p) => p.id).toList();
    final optionRows = await SupabaseBootstrap.client
        .from('poll_options')
        .select('*')
        .inFilter('poll_id', pollIds);
    final voteRows = await SupabaseBootstrap.client
        .from('poll_votes')
        .select('*')
        .inFilter('poll_id', pollIds);

    final options = (optionRows as List)
        .map((r) => PollOption.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
    final votes = (voteRows as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();

    return PollBundle(polls: polls, options: options, votes: votes);
  }

  Future<void> castVote({
    required String pollId,
    required String optionId,
    required String voterId,
    required String flatNumber,
    required int currentVotesCount,
  }) async {
    if (!Env.isConfigured) return;

    await SupabaseBootstrap.client.from('poll_votes').insert({
      'poll_id': pollId,
      'option_id': optionId,
      'voter_id': voterId,
      'voter_type': 'resident',
      'flat_number': flatNumber,
    });

    await SupabaseBootstrap.client
        .from('poll_options')
        .update({'votes_count': currentVotesCount + 1})
        .eq('id', optionId);
  }

  Future<PollBundle> fetchStandardPolls(String societyId) async {
    final bundle = await fetchForSociety(societyId);
    final standardIds = bundle.polls.where((p) => !p.isElection).map((p) => p.id).toSet();
    return PollBundle(
      polls: bundle.polls.where((p) => standardIds.contains(p.id)).toList(),
      options: bundle.options.where((o) => standardIds.contains(o.pollId)).toList(),
      votes: bundle.votes.where((v) => standardIds.contains(v['poll_id'])).toList(),
    );
  }

  Future<String> createStandardPoll({
    required String societyId,
    required String adminName,
    required String question,
    String? description,
    required List<String> optionTexts,
  }) async {
    if (!Env.isConfigured) throw StateError('Not configured');

    final opts = optionTexts.map((o) => o.trim()).where((o) => o.isNotEmpty).toList();
    if (opts.length < 2) throw StateError('Add at least two options');

    final poll = await SupabaseBootstrap.client
        .from('polls')
        .insert({
          'question': question.trim(),
          'description': description?.trim().isEmpty == true ? null : description?.trim(),
          'created_by': adminName,
          'society_id': societyId,
          'poll_kind': 'standard',
          'is_active': true,
        })
        .select('id')
        .single();

    final pollId = poll['id'] as String;
    await SupabaseBootstrap.client.from('poll_options').insert(
      opts.map((text) => {'poll_id': pollId, 'option_text': text, 'votes_count': 0}).toList(),
    );

    await SupabaseBootstrap.client.from('notifications').insert({
      'title': 'New Poll',
      'message': 'Vote now: ${question.trim()}',
      'type': 'poll',
      'target_type': 'all',
      'created_by': adminName,
      'society_id': societyId,
    });

    return pollId;
  }

  Future<void> closePoll(String pollId) async {
    if (!Env.isConfigured) return;
    await SupabaseBootstrap.client.from('polls').update({'is_active': false}).eq('id', pollId);
  }

  Future<Map<String, ({String name, String flatNumber})>> fetchVoterProfiles(
    Iterable<String> memberIds,
  ) async {
    if (!Env.isConfigured || memberIds.isEmpty) return {};

    final ids = memberIds.toSet().toList();
    final mems = await SupabaseBootstrap.client
        .from('members')
        .select('id, name, flat_id')
        .inFilter('id', ids);

    final flatIds = (mems as List)
        .map((m) => m['flat_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    final flatNumById = <String, String>{};
    if (flatIds.isNotEmpty) {
      final flats = await SupabaseBootstrap.client
          .from('flats')
          .select('id, flat_number')
          .inFilter('id', flatIds);
      for (final f in flats as List) {
        flatNumById[f['id'] as String] = f['flat_number'] as String;
      }
    }

    final out = <String, ({String name, String flatNumber})>{};
    for (final m in mems as List) {
      final id = m['id'] as String;
      final flatId = m['flat_id'] as String?;
      out[id] = (
        name: (m['name'] as String?)?.trim().isNotEmpty == true ? m['name'] as String : 'Member',
        flatNumber: flatId != null ? (flatNumById[flatId] ?? '') : '',
      );
    }
    return out;
  }
}
