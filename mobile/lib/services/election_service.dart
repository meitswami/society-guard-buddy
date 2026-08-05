import '../core/config/env.dart';
import '../core/supabase/supabase_bootstrap.dart';
import '../models/poll_models.dart';
import '../utils/election_governance.dart';
import '../utils/election_tally.dart';
import '../utils/voting_method_consent.dart';

class ElectionBundle {
  const ElectionBundle({
    required this.elections,
    required this.options,
    required this.ballots,
    this.documents = const [],
  });

  final List<SocietyPoll> elections;
  final List<Map<String, dynamic>> options;
  final List<Map<String, dynamic>> ballots;
  final List<Map<String, dynamic>> documents;
}

class ElectionService {
  Future<ElectionBundle> fetchForSociety(String societyId) async {
    if (!Env.isConfigured) {
      return const ElectionBundle(elections: [], options: [], ballots: []);
    }

    final pollRows = await SupabaseBootstrap.client
        .from('polls')
        .select('*')
        .eq('society_id', societyId)
        .eq('poll_kind', 'election')
        .order('created_at', ascending: false);

    final elections = (pollRows as List)
        .map((r) => SocietyPoll.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();

    if (elections.isEmpty) {
      return const ElectionBundle(elections: [], options: [], ballots: []);
    }

    final ids = elections.map((e) => e.id).toList();
    final optionRows = await SupabaseBootstrap.client
        .from('poll_options')
        .select('*')
        .inFilter('poll_id', ids);
    final ballotRows = await SupabaseBootstrap.client
        .from('poll_election_ballots')
        .select('*')
        .inFilter('poll_id', ids);
    final docRows = await SupabaseBootstrap.client
        .from('poll_documents')
        .select('*')
        .inFilter('poll_id', ids)
        .order('sort_order', ascending: true);

    return ElectionBundle(
      elections: elections,
      options: (optionRows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList(),
      ballots: (ballotRows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList(),
      documents: (docRows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList(),
    );
  }

  Future<Map<String, dynamic>?> fetchPollRaw(String pollId) async {
    final row = await SupabaseBootstrap.client.from('polls').select('*').eq('id', pollId).maybeSingle();
    if (row == null) return null;
    return Map<String, dynamic>.from(row);
  }

  Future<void> submitBallot({
    required String pollId,
    required String voterId,
    required String flatId,
    required String flatNumber,
    required String voterPhone,
    required Map<String, Map<String, int>> rankings,
    required List<Map<String, dynamic>> existingBallots,
  }) async {
    if (!Env.isConfigured) return;

    final phone = voterPhone.replaceAll(RegExp(r'\D'), '');
    final existing = existingBallots.where((b) => b['poll_id'] == pollId && b['voter_id'] == voterId).toList();

    if (existing.isEmpty && phone.isNotEmpty) {
      final phoneVote = existingBallots.where((b) {
        if (b['poll_id'] != pollId) return false;
        final p = (b['voter_phone'] as String?)?.replaceAll(RegExp(r'\D'), '') ?? '';
        return p == phone;
      });
      if (phoneVote.isNotEmpty) {
        throw StateError('You have already voted on this election');
      }
    }

    final flatBallots = existingBallots.where((b) => b['poll_id'] == pollId && b['flat_id'] == flatId);
    final distinctOthers = flatBallots.where((b) => b['voter_id'] != voterId).map((b) => b['voter_id']).toSet();
    if (existing.isEmpty && distinctOthers.length >= 2) {
      throw StateError('This flat already has two ballots');
    }

    await SupabaseBootstrap.client.from('poll_election_ballots').upsert({
      'poll_id': pollId,
      'voter_id': voterId,
      'flat_id': flatId,
      'flat_number': flatNumber,
      'voter_phone': phone.isEmpty ? null : phone,
      'rankings': rankings,
    }, onConflict: 'poll_id,voter_id');
  }

  Future<void> selfNominate({
    required String pollId,
    required String post,
    required String memberId,
    required String memberName,
    required String flatId,
    required String flatNumber,
    required String nominatedBy,
    required String nominationStatement,
    required List<Map<String, dynamic>> existingOptions,
  }) async {
    if (!Env.isConfigured) return;

    final statement = nominationStatement.trim();
    if (statement.length < 20) {
      throw StateError('Write at least 20 characters explaining why you should be chosen');
    }

    final dup = existingOptions.any(
      (o) => o['poll_id'] == pollId && o['election_post'] == post && o['member_id'] == memberId,
    );
    if (dup) throw StateError('Already nominated for this post');

    await SupabaseBootstrap.client.from('poll_options').insert({
      'poll_id': pollId,
      'option_text': memberName.trim(),
      'election_post': post,
      'votes_count': 0,
      'member_id': memberId,
      'flat_id': flatId,
      'flat_number': flatNumber,
      'nominated_by': nominatedBy,
      'nomination_statement': statement,
    });
  }

  Future<String> createElection({
    required String societyId,
    required String adminName,
    required String question,
    String? description,
    DateTime? nominationStarts,
    DateTime? nominationEnds,
    DateTime? votingStarts,
    DateTime? votingEnds,
    String? termFrom,
    String? termTo,
    Map<String, int>? winningVotes,
    Map<String, bool>? openPosts,
  }) async {
    if (!Env.isConfigured) throw StateError('Not configured');

    final row = await SupabaseBootstrap.client
        .from('polls')
        .insert({
          'question': question.trim(),
          'description': description?.trim().isEmpty == true ? null : description?.trim(),
          'created_by': adminName,
          'society_id': societyId,
          'poll_kind': 'election',
          'election_committee_seats': 0,
          'target_committee_size': 15,
          'election_phase': 'nomination',
          'is_active': true,
          'nomination_starts_at': nominationStarts?.toIso8601String(),
          'nomination_ends_at': nominationEnds?.toIso8601String(),
          'voting_starts_at': votingStarts?.toIso8601String(),
          'voting_ends_at': votingEnds?.toIso8601String(),
          'election_term_from': termFrom,
          'election_term_to': termTo,
          'open_posts': openPosts ?? defaultOpenPosts,
          'winning_votes': winningVotes ??
              {
                'president': 0,
                'secretary': 0,
                'treasurer': 0,
              },
        })
        .select('id')
        .single();

    final pollId = row['id'] as String;

    await SupabaseBootstrap.client.from('notifications').insert({
      'title': 'Society election — nomination open',
      'message': 'Propose yourself for President, Secretary or Treasurer: ${question.trim()}',
      'type': 'poll',
      'target_type': 'all',
      'created_by': adminName,
      'society_id': societyId,
    });

    return pollId;
  }

  Future<void> updateSchedule({
    required String pollId,
    required DateTime nominationStarts,
    required DateTime nominationEnds,
    required DateTime votingStarts,
    required DateTime votingEnds,
    required Map<String, int> winningVotes,
  }) async {
    if (!Env.isConfigured) return;
    await SupabaseBootstrap.client.from('polls').update({
      'nomination_starts_at': nominationStarts.toIso8601String(),
      'nomination_ends_at': nominationEnds.toIso8601String(),
      'voting_starts_at': votingStarts.toIso8601String(),
      'voting_ends_at': votingEnds.toIso8601String(),
      'winning_votes': winningVotes,
    }).eq('id', pollId);
  }

  Future<List<VotingMethodConsentRow>> fetchVotingMethodConsents(String pollId) async {
    if (!Env.isConfigured) return [];
    final rows = await SupabaseBootstrap.client
        .from('election_voting_method_consents')
        .select('id, poll_id, member_id, choice, member_name, flat_number, created_at')
        .eq('poll_id', pollId)
        .order('created_at', ascending: true);
    return (rows as List)
        .map((r) => VotingMethodConsentRow.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<int> countEligibleMembers(String societyId) async {
    if (!Env.isConfigured) return 0;
    final rows = await SupabaseBootstrap.client
        .from('members')
        .select('id, flats!inner(society_id)')
        .eq('flats.society_id', societyId)
        .isFilter('date_leave', null);
    return (rows as List).length;
  }

  Future<void> openVotingMethodConsent({
    required String pollId,
    required String societyId,
    required String openedBy,
  }) async {
    if (!Env.isConfigured) return;
    await SupabaseBootstrap.client.from('polls').update({
      'voting_method_consent_open': true,
      'voting_method_consent_opened_at': DateTime.now().toIso8601String(),
      'voting_method_consent_opened_by': openedBy,
    }).eq('id', pollId).isFilter('voting_method', null);

    await _logAudit(
      societyId: societyId,
      pollId: pollId,
      eventType: 'voting_method_consent_opened',
      actorType: 'admin',
      actorName: openedBy,
      payload: {
        'options': [votingMethodSecretBallot, votingMethodShowOfHands],
      },
    );
  }

  Future<void> submitVotingMethodConsent({
    required String societyId,
    required String pollId,
    required String memberId,
    required ElectionVotingMethod choice,
    String? memberName,
    String? flatNumber,
  }) async {
    if (!Env.isConfigured) return;
    try {
      await SupabaseBootstrap.client.from('election_voting_method_consents').insert({
        'society_id': societyId,
        'poll_id': pollId,
        'member_id': memberId,
        'choice': choice,
        'member_name': memberName,
        'flat_number': flatNumber,
      });
    } catch (e) {
      final msg = e.toString();
      if (RegExp(r'duplicate|unique|immutable', caseSensitive: false).hasMatch(msg)) {
        throw StateError('You have already recorded your consent for this election.');
      }
      rethrow;
    }

    await _logAudit(
      societyId: societyId,
      pollId: pollId,
      eventType: 'voting_method_consent_cast',
      actorType: 'resident',
      actorId: memberId,
      actorName: memberName,
      payload: {
        'choice': choice,
        'option': choice == votingMethodSecretBallot ? 'A' : 'B',
      },
    );
  }

  Future<void> finalizeVotingMethodFromConsent({
    required String pollId,
    required String societyId,
    required ElectionVotingMethod method,
    required String recordedBy,
    required int eligibleMemberCount,
    required int consentTotal,
    bool allowPartial = false,
    bool separateOfficeVotes = false,
  }) async {
    if (!Env.isConfigured) return;
    if (!allowPartial && consentTotal < eligibleMemberCount) {
      throw StateError(
        'Consent incomplete: $consentTotal of $eligibleMemberCount eligible members have consented.',
      );
    }

    await SupabaseBootstrap.client.rpc('record_election_voting_method', params: {
      'p_poll_id': pollId,
      'p_method': method,
      'p_recorded_by': recordedBy,
      'p_separate_office_votes': separateOfficeVotes,
    });

    await SupabaseBootstrap.client.from('polls').update({
      'voting_method_consent_open': false,
    }).eq('id', pollId);

    await _logAudit(
      societyId: societyId,
      pollId: pollId,
      eventType: 'voting_method_finalized',
      actorType: 'admin',
      actorName: recordedBy,
      payload: {
        'method': method,
        'option': method == votingMethodSecretBallot ? 'A' : 'B',
        'consent_total': consentTotal,
        'eligible_member_count': eligibleMemberCount,
        'allow_partial': allowPartial,
      },
    );
  }

  Future<void> _logAudit({
    required String societyId,
    String? pollId,
    required String eventType,
    String? actorType,
    String? actorId,
    String? actorName,
    Map<String, dynamic>? payload,
  }) async {
    try {
      await SupabaseBootstrap.client.rpc('log_election_audit_event', params: {
        'p_society_id': societyId,
        'p_poll_id': pollId,
        'p_event_type': eventType,
        'p_actor_type': actorType,
        'p_actor_id': actorId,
        'p_actor_name': actorName,
        'p_payload': payload ?? {},
      });
    } catch (_) {
      // Audit failure must not block the primary election action.
    }
  }

  Future<void> startVoting(String pollId, {String? societyId, String? adminName, String? title}) async {
    if (!Env.isConfigured) return;
    final raw = await fetchPollRaw(pollId);
    final method = raw?['voting_method'] as String?;
    if (method == null || method.isEmpty) {
      throw StateError('Record the voting method (Secret Ballot or Show of Hands) before opening the poll.');
    }
    await SupabaseBootstrap.client.from('polls').update({
      'election_phase': 'voting',
      'is_active': true,
    }).eq('id', pollId);

    if (societyId != null && adminName != null && title != null) {
      await SupabaseBootstrap.client.from('notifications').insert({
        'title': 'Society election — voting open',
        'message': 'Cast your ranked ballot: $title',
        'type': 'poll',
        'target_type': 'all',
        'created_by': adminName,
        'society_id': societyId,
      });
    }
  }

  Future<ElectionResultsPayload> closeAndTally({
    required String pollId,
    required List<Map<String, dynamic>> options,
    required List<Map<String, dynamic>> ballots,
    required int committeeSeats,
    Map<String, int> winningVotes = const {},
    String? societyId,
    String? adminName,
    String? title,
  }) async {
    if (!Env.isConfigured) throw StateError('Not configured');

    final pollBallots = ballots.where((b) => b['poll_id'] == pollId).toList();
    final pollOpts = options.where((o) => o['poll_id'] == pollId).toList();
    final results = tallyElection(
      options: pollOpts,
      ballots: pollBallots,
      committeeSeats: committeeSeats,
      winningVotes: winningVotes,
    );

    await SupabaseBootstrap.client.from('polls').update({
      'is_active': false,
      'election_phase': 'closed',
      'election_results': results.toJson(),
    }).eq('id', pollId);

    if (societyId != null && adminName != null && title != null) {
      await SupabaseBootstrap.client.from('notifications').insert({
        'title': 'Society election closed',
        'message': 'Voting has closed for: $title',
        'type': 'poll',
        'target_type': 'all',
        'created_by': adminName,
        'society_id': societyId,
      });
    }

    return results;
  }

  Future<void> volunteerForCommittee({
    required String pollId,
    required Map<String, dynamic> results,
    required String memberName,
    required String flatNumber,
    String? flatId,
    String? memberId,
  }) async {
    if (!Env.isConfigured) return;

    final formation = Map<String, dynamic>.from(formationOf(results) ?? emptyFormationState());
    final voluntary = List<Map<String, dynamic>>.from(
      (formation['voluntary'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? [],
    );
    final key = 'vol-${memberId ?? memberName}-$flatNumber';
    if (voluntary.any((v) =>
        v['key'] == key || (memberId != null && memberId.isNotEmpty && v['member_id'] == memberId))) {
      throw StateError('You are already listed as a volunteer');
    }
    voluntary.add({
      'key': key,
      'name': memberName.trim(),
      'flat_number': flatNumber.isEmpty ? null : flatNumber,
      'flat_id': flatId,
      'member_id': memberId,
      'source': 'voluntary',
    });
    formation['voluntary'] = voluntary;
    final nextResults = Map<String, dynamic>.from(results)..['formation'] = formation;
    await SupabaseBootstrap.client.from('polls').update({
      'election_results': nextResults,
    }).eq('id', pollId);
  }

  Future<void> publishToCommittee({
    required String societyId,
    required String pollId,
    required ElectionResultsPayload results,
    required List<Map<String, dynamic>> options,
    String? termFrom,
    String? termTo,
    String? adminName,
    String? title,
  }) async {
    if (!Env.isConfigured) return;

    final optById = {for (final o in options) o['id'] as String: o};
    final termFromVal = termFrom ?? DateTime.now().toIso8601String().substring(0, 10);
    final inserts = <Map<String, dynamic>>[];
    var sort = 0;

    const execOrder = ['president', 'secretary', 'treasurer', 'vice_president'];
    const postToPosition = {
      'president': 'President',
      'vice_president': 'Vice-President',
      'secretary': 'Secretary',
      'treasurer': 'Treasurer',
    };

    ElectedWinner? winnerFor(String post) => switch (post) {
          'president' => results.president,
          'vice_president' => results.vicePresident,
          'secretary' => results.secretary,
          'treasurer' => results.treasurer,
          _ => null,
        };

    for (final post in execOrder) {
      final w = winnerFor(post);
      if (w == null) continue;
      final opt = optById[w.optionId];
      inserts.add({
        'society_id': societyId,
        'flat_id': opt?['flat_id'],
        'flat_number': opt?['flat_number'],
        'flat_owner_name': opt?['option_text'] ?? w.name,
        'name': w.name,
        'position': postToPosition[post] ?? post,
        'selection_type': 'elected',
        'term_from': termFromVal,
        'term_to': termTo,
        'sort_order': sort++,
        'is_active': true,
        'source_poll_id': pollId,
        'source_option_id': w.optionId,
      });
    }

    for (final w in results.committee) {
      final opt = optById[w.optionId];
      inserts.add({
        'society_id': societyId,
        'flat_id': opt?['flat_id'],
        'flat_number': opt?['flat_number'],
        'flat_owner_name': opt?['option_text'] ?? w.name,
        'name': w.name,
        'position': 'Committee Member',
        'selection_type': 'elected',
        'term_from': termFromVal,
        'term_to': termTo,
        'sort_order': sort++,
        'is_active': true,
        'source_poll_id': pollId,
        'source_option_id': w.optionId,
      });
    }

    if (inserts.isEmpty) throw StateError('No winners to publish');

    await SupabaseBootstrap.client.from('committee_members').insert(inserts);
    await SupabaseBootstrap.client.from('polls').update({
      'election_phase': 'applied',
      'election_applied_at': DateTime.now().toIso8601String(),
    }).eq('id', pollId);

    if (adminName != null && title != null) {
      await SupabaseBootstrap.client.from('notifications').insert({
        'title': 'New committee published',
        'message': 'Elected office-bearers are now on the Committee roster: $title',
        'type': 'poll',
        'target_type': 'all',
        'created_by': adminName,
        'society_id': societyId,
      });
    }
  }
}
