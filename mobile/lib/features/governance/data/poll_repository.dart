
import 'package:flutter/foundation.dart';

import '../../../core/supabase/db.dart';
import '../logic/election_apply.dart';
import '../logic/election_eligibility.dart';
import '../logic/election_governance.dart';
import '../logic/election_tally.dart';
import '../logic/meeting_logic.dart' show sanitizeStorageFileName;
import '../logic/voting_method_consent.dart';
import '../models/poll_models.dart';
import 'gov_backend.dart';

/// Supabase access for polls & elections — same queries as web `PollManager.tsx`,
/// `ElectionModule.tsx`, `electionApply.ts`, `electionVotingMethodConsent.ts`,
/// `pollDocuments.ts` and `ElectionResultsBanner.tsx`.
class PollRepository {
  const PollRepository(this.societyId);

  final String societyId;

  /// Web `loadAll`.
  Future<PollsBundle> loadAll() async {
    if (!dbReady) return const PollsBundle();
    final polls = rowsOf(
      await db.from('polls').select('*').eq('society_id', societyId).order('created_at', ascending: false),
    ).map(PollRow.new).toList();
    final pollIds = polls.map((p) => p.id).toList();
    final electionIds = polls.where((p) => p.isElection).map((p) => p.id).toList();
    if (pollIds.isEmpty) return PollsBundle(polls: polls);

    final results = await Future.wait<List<Map<String, dynamic>>>([
      db.from('poll_options').select('*').inFilter('poll_id', pollIds).then(rowsOf),
      db.from('poll_votes').select('*').inFilter('poll_id', pollIds).then(rowsOf),
      electionIds.isEmpty
          ? Future.value(const <Map<String, dynamic>>[])
          : db.from('poll_election_ballots').select('*').inFilter('poll_id', electionIds).then(rowsOf),
      fetchPollDocumentsRaw(pollIds).catchError((Object _) => const <Map<String, dynamic>>[]),
    ]);
    final options = results[0].map(PollOptionRow.fromJson).toList();
    final votes = results[1].map(PollVoteRow.fromJson).toList();
    final ballots = results[2].map(BallotRow.fromJson).toList();
    final docs = results[3].map(PollDocumentRow.fromJson).toList();

    final ids = {
      ...votes.map((v) => v.voterId),
      ...ballots.map((b) => b.voterId),
    }.where((s) => s.isNotEmpty).toList();
    final profiles = <String, VoterProfile>{};
    if (ids.isNotEmpty) {
      final mems = rowsOf(await db.from('members').select('id, name, flat_id').inFilter('id', ids));
      final flatIds = mems.map((m) => m['flat_id']).whereType<String>().toSet().toList();
      final flatRows = flatIds.isEmpty
          ? const <Map<String, dynamic>>[]
          : rowsOf(await db.from('flats').select('id, flat_number').inFilter('id', flatIds));
      final flatNum = {for (final f in flatRows) '${f['id']}': (f['flat_number'] ?? '').toString()};
      for (final m in mems) {
        final name = (m['name'] ?? '').toString().trim();
        profiles['${m['id']}'] = VoterProfile(
          name: name.isEmpty ? 'Member' : name,
          flatNumber: flatNum['${m['flat_id']}'] ?? '',
        );
      }
    }
    return PollsBundle(
      polls: polls,
      options: options,
      votes: votes,
      ballots: ballots,
      documents: docs,
      voterProfiles: profiles,
    );
  }

  // --- standard polls -----------------------------------------------------

  /// Web `addPoll` (+ "New Poll" notification and push).
  Future<void> createStandardPoll({
    required String question,
    required String description,
    required List<String> options,
    required String adminName,
  }) async {
    final notifyTitle = question.trim();
    final poll = await db
        .from('polls')
        .insert({
          'question': question,
          'description': description.isEmpty ? null : description,
          'created_by': adminName,
          'society_id': societyId,
          'poll_kind': 'standard',
        })
        .select()
        .single();
    final opts = options.where((o) => o.trim().isNotEmpty).map((o) => {'poll_id': poll['id'], 'option_text': o.trim()});
    await db.from('poll_options').insert(opts.toList());
    try {
      await db.from('notifications').insert({
        'title': 'New Poll',
        'message': 'Vote now: $notifyTitle',
        'type': 'poll',
        'target_type': 'all',
        'created_by': adminName,
        'society_id': societyId,
      });
    } catch (e) {
      debugPrint('poll notification failed: $e');
    }
    await GovBackend.invokePush(title: 'New Poll', message: 'Vote now: $notifyTitle', societyId: societyId);
  }

  /// Web `castVote` (insert vote + bump the option counter).
  Future<void> castVote({
    required String pollId,
    required String optionId,
    required String voterId,
    required String flatNumber,
    required int currentCount,
  }) async {
    await db.from('poll_votes').insert({
      'poll_id': pollId,
      'option_id': optionId,
      'voter_id': voterId,
      'voter_type': 'resident',
      'flat_number': flatNumber,
    });
    await db.from('poll_options').update({'votes_count': currentCount + 1}).eq('id', optionId);
  }

  Future<void> closePoll(String pollId) => db.from('polls').update({'is_active': false}).eq('id', pollId);

  // --- poll documents -----------------------------------------------------

  Future<List<Map<String, dynamic>>> fetchPollDocumentsRaw(List<String> pollIds) async {
    if (pollIds.isEmpty) return const [];
    return rowsOf(
      await db
          .from('poll_documents')
          .select('*')
          .inFilter('poll_id', pollIds)
          .order('sort_order', ascending: true)
          .order('created_at', ascending: true),
    );
  }

  /// Web `uploadPollDocument`; returns false when upload or insert failed.
  Future<bool> uploadPollDocument({
    required String pollId,
    required Uint8List bytes,
    required String fileName,
    required String? mimeType,
    required String title,
    required String docKind,
    required String createdBy,
    required int sortOrder,
  }) async {
    var safe = sanitizeStorageFileName(fileName);
    if (safe.length > 120) safe = safe.substring(0, 120);
    final path = 'poll-documents/$societyId/$pollId/${GovBackend.newId()}_$safe';
    final url = await GovBackend.uploadToNotificationMedia(path, bytes, contentType: mimeType);
    if (url == null) return false;
    try {
      await db.from('poll_documents').insert({
        'poll_id': pollId,
        'society_id': societyId,
        'title': title.trim().isEmpty ? fileName : title.trim(),
        'doc_kind': docKind,
        'file_url': url,
        'file_name': fileName,
        'mime_type': mimeType,
        'sort_order': sortOrder,
        'created_by': createdBy,
      }).select().single();
      return true;
    } catch (e) {
      debugPrint('poll document insert failed: $e');
      return false;
    }
  }

  Future<void> deletePollDocument(String id) => db.from('poll_documents').delete().eq('id', id);

  // --- elections ----------------------------------------------------------

  /// Web `addElection`: nomination phase election + optional seed candidates.
  Future<Map<String, dynamic>> createElection({
    required String question,
    required String description,
    required String adminName,
    required DateTime nominationStarts,
    required DateTime nominationEnds,
    required DateTime votingStarts,
    required DateTime votingEnds,
    required String termFrom,
    required String termTo,
    required Map<String, List<String>> seedCandidates,
  }) async {
    final poll = await db
        .from('polls')
        .insert({
          'question': question.trim(),
          'description': description.trim().isEmpty ? null : description.trim(),
          'created_by': adminName,
          'society_id': societyId,
          'poll_kind': 'election',
          'election_committee_seats': ByeLaw.executiveMembers,
          'target_committee_size': defaultTargetCommitteeSize,
          'bye_law_mode': true,
          'separate_office_votes': false,
          'election_phase': 'nomination',
          'is_active': true,
          'nomination_starts_at': jsIsoString(nominationStarts),
          'nomination_ends_at': jsIsoString(nominationEnds),
          'voting_starts_at': jsIsoString(votingStarts),
          'voting_ends_at': jsIsoString(votingEnds),
          'election_term_from': termFrom.isEmpty ? null : termFrom,
          'election_term_to': termTo.isEmpty ? null : termTo,
          'open_posts': defaultOpenPosts,
          'winning_votes': defaultWinningVotes,
        })
        .select()
        .single();
    final rows = <Map<String, dynamic>>[];
    for (final post in ElectionPosts.managementCommittee) {
      for (final name in (seedCandidates[post] ?? const <String>[]).map((s) => s.trim()).where((s) => s.isNotEmpty)) {
        rows.add({'poll_id': poll['id'], 'option_text': name, 'election_post': post, 'votes_count': 0});
      }
    }
    if (rows.isNotEmpty) await db.from('poll_options').insert(rows);
    return poll;
  }

  Future<void> updateSchedule({
    required String pollId,
    required DateTime nominationStarts,
    required DateTime nominationEnds,
    required DateTime votingStarts,
    required DateTime votingEnds,
  }) =>
      db.from('polls').update({
        'nomination_starts_at': jsIsoString(nominationStarts),
        'nomination_ends_at': jsIsoString(nominationEnds),
        'voting_starts_at': jsIsoString(votingStarts),
        'voting_ends_at': jsIsoString(votingEnds),
      }).eq('id', pollId);

  Future<void> insertNomination(Map<String, dynamic> row) => db.from('poll_options').insert(row);

  Future<void> insertBallot(Map<String, dynamic> row) => db.from('poll_election_ballots').insert(row);

  Future<void> patchPoll(String pollId, Map<String, dynamic> patch) => db.from('polls').update(patch).eq('id', pollId);

  /// Web `publishToCommittee` → `applyElectionToCommittee`. Returns an error or null.
  Future<String?> applyElectionToCommittee({
    required String pollId,
    required Map<String, dynamic> results,
    required List<PollOptionRow> options,
    required String? termFrom,
    required String? termTo,
  }) async {
    final applyOpts = options.map((o) => o.apply).toList();
    final from = (termFrom != null && termFrom.isNotEmpty) ? termFrom.substring(0, termFrom.length >= 10 ? 10 : termFrom.length) : utcIsoDate();
    final to = (termTo != null && termTo.isNotEmpty) ? termTo : null;
    final photos = await GovBackend.fetchMemberPhotoMap(applyMemberIds(applyOpts, results));
    final inserts = buildCommitteeInserts(
      societyId: societyId,
      pollId: pollId,
      results: results,
      options: applyOpts,
      termFrom: from,
      termTo: to,
      photoByMemberId: photos,
    );
    if (inserts.isEmpty) return 'No winners to publish.';

    try {
      final prior = rowsOf(
        await db.from('committee_members').select('id, term_from, term_to').eq('society_id', societyId).eq('is_active', true),
      );
      final retire = retireIdsFor(prior, from);
      if (retire.isNotEmpty) {
        try {
          await db.from('committee_members').update({'term_to': priorTermTo(from)}).inFilter('id', retire);
        } catch (e) {
          debugPrint('Could not close previous committee term: $e');
        }
      }
    } catch (e) {
      debugPrint('Could not load previous committee for retirement: $e');
    }

    try {
      await db.from('committee_members').insert(inserts);
    } catch (e) {
      return GovBackend.errorText(e);
    }
    try {
      await db.from('polls').update({
        'election_phase': 'applied',
        'election_applied_at': jsIsoString(DateTime.now()),
      }).eq('id', pollId);
    } catch (e) {
      return GovBackend.errorText(e);
    }
    return null;
  }

  /// Persist `election_results` with a new formation (web `CommitteeFormationPanel.persistFormation`).
  Future<void> saveResults(String pollId, Map<String, dynamic> results) =>
      db.from('polls').update({'election_results': results}).eq('id', pollId);

  /// Closed / applied elections with results for the admin banner (latest three).
  Future<List<Map<String, dynamic>>> latestResultsPolls() async {
    if (!dbReady) return const [];
    return rowsOf(
      await db
          .from('polls')
          .select('id, question, election_results, election_phase, election_applied_at')
          .eq('society_id', societyId)
          .eq('poll_kind', 'election')
          .inFilter('election_phase', ['closed', 'applied'])
          .not('election_results', 'is', null)
          .order('created_at', ascending: false)
          .limit(3),
    );
  }

  Future<Map<String, String>> optionMemberIds(List<String> pollIds) async {
    if (pollIds.isEmpty || !dbReady) return {};
    final opts = rowsOf(await db.from('poll_options').select('id, member_id').inFilter('poll_id', pollIds));
    return {
      for (final o in opts)
        if (o['member_id'] != null) '${o['id']}': '${o['member_id']}',
    };
  }

  // --- voting method consent ----------------------------------------------

  Future<({List<VotingMethodConsentRow> rows, String? error})> fetchConsents(String pollId) async {
    if (!dbReady) return (rows: const <VotingMethodConsentRow>[], error: null);
    try {
      final rows = rowsOf(
        await db
            .from('election_voting_method_consents')
            .select('id, poll_id, member_id, choice, member_name, flat_number, created_at')
            .eq('poll_id', pollId)
            .order('created_at', ascending: true),
      );
      return (rows: rows.map(VotingMethodConsentRow.fromJson).toList(), error: null);
    } catch (e) {
      return (rows: const <VotingMethodConsentRow>[], error: GovBackend.errorText(e));
    }
  }

  /// Web `openVotingMethodConsent`.
  Future<String?> openConsent({required String pollId, required String openedBy}) async {
    try {
      await db
          .from('polls')
          .update({
            'voting_method_consent_open': true,
            'voting_method_consent_opened_at': jsIsoString(DateTime.now()),
            'voting_method_consent_opened_by': openedBy,
          })
          .eq('id', pollId)
          .isFilter('voting_method', null);
    } catch (e) {
      return GovBackend.errorText(e);
    }
    await GovBackend.logElectionAudit(
      societyId: societyId,
      pollId: pollId,
      eventType: 'voting_method_consent_opened',
      actorType: 'admin',
      actorName: openedBy,
      payload: {
        'options': ['secret_ballot', 'show_of_hands'],
      },
    );
    return null;
  }

  /// Web `submitVotingMethodConsent`.
  Future<String?> submitConsent({
    required String pollId,
    required String memberId,
    required String choice,
    String? memberName,
    String? flatNumber,
    bool hi = false,
  }) async {
    try {
      await db.from('election_voting_method_consents').insert({
        'society_id': societyId,
        'poll_id': pollId,
        'member_id': memberId,
        'choice': choice,
        'member_name': memberName,
        'flat_number': flatNumber,
      });
    } catch (e) {
      final msg = GovBackend.errorText(e);
      if (isDuplicateConsentError(msg)) {
        return hi
            ? 'आप इस चुनाव के लिए पहले ही सहमति दर्ज कर चुके हैं।'
            : 'You have already recorded your consent for this election.';
      }
      return msg;
    }
    await GovBackend.logElectionAudit(
      societyId: societyId,
      pollId: pollId,
      eventType: 'voting_method_consent_cast',
      actorType: 'resident',
      actorId: memberId,
      actorName: memberName,
      payload: {'choice': choice, 'option': choice == VotingMethods.secretBallot ? 'A' : 'B'},
    );
    return null;
  }

  /// Web `finalizeVotingMethodFromConsent`.
  Future<String?> finalizeConsent({
    required String pollId,
    required String method,
    required String recordedBy,
    required int eligibleMemberCount,
    required int consentTotal,
    required bool allowPartial,
    required bool separateOfficeVotes,
    bool hi = false,
  }) async {
    final incomplete = consentIncompleteError(
      consentTotal: consentTotal,
      eligibleMemberCount: eligibleMemberCount,
      allowPartial: allowPartial,
      hi: hi,
    );
    if (incomplete != null) return incomplete;
    final err = await GovBackend.recordElectionVotingMethod(
      pollId: pollId,
      method: method,
      recordedBy: recordedBy,
      separateOfficeVotes: separateOfficeVotes,
    );
    if (err != null) return err;
    try {
      await db.from('polls').update({'voting_method_consent_open': false}).eq('id', pollId);
    } catch (_) {}
    await GovBackend.logElectionAudit(
      societyId: societyId,
      pollId: pollId,
      eventType: 'voting_method_finalized',
      actorType: 'admin',
      actorName: recordedBy,
      payload: {
        'method': method,
        'option': method == VotingMethods.secretBallot ? 'A' : 'B',
        'consent_total': consentTotal,
        'eligible_member_count': eligibleMemberCount,
        'allow_partial': allowPartial,
      },
    );
    return null;
  }

  /// Admin records the method by meeting resolution (web `recordByResolution`).
  Future<String?> recordByResolution({
    required String pollId,
    required String method,
    required String recordedBy,
    required bool separateOfficeVotes,
  }) async {
    final err = await GovBackend.recordElectionVotingMethod(
      pollId: pollId,
      method: method,
      recordedBy: recordedBy,
      separateOfficeVotes: separateOfficeVotes,
    );
    if (err != null) return err;
    try {
      await db.from('polls').update({'voting_method_consent_open': false}).eq('id', pollId);
    } catch (_) {}
    return null;
  }

  // --- tally ----------------------------------------------------------------

  /// Tally a poll (web `closeElection` → `tallyElection`).
  Map<String, dynamic> tally(PollRow poll, List<PollOptionRow> options, List<BallotRow> ballots) {
    final seats = poll.electionCommitteeSeats;
    return tallyElection(
      options.map((o) => o.tally).toList(),
      ballots.map((b) => b.tally).toList(),
      separateOfficeVotes: poll.separateOfficeVotes,
      committeeSeats: seats > 0 ? seats : ByeLaw.executiveMembers,
    );
  }

  Future<void> notify(ElectionNotifyEvent event, {required String createdBy, required String electionTitle}) =>
      GovBackend.notifyElectionEvent(
        event: event,
        societyId: societyId,
        createdBy: createdBy,
        electionTitle: electionTitle,
      );
}
