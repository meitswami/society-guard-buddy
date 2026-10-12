import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../data/gov_backend.dart';
import '../data/poll_repository.dart';
import '../logic/election_eligibility.dart';
import '../logic/election_governance.dart';
import '../logic/election_tally.dart';
import '../models/poll_models.dart';
import '../widgets/election_results_banner.dart';
import '../widgets/gov_widgets.dart';
import '../widgets/poll_documents_panel.dart';
import '../widgets/voting_charter_panel.dart';
import '../widgets/voting_method_consent_panel.dart';
import 'committee_formation_panel.dart';

/// Port of web `ElectionModule.tsx` (embedded in the polls page).
class ElectionSection extends StatefulWidget {
  const ElectionSection({
    super.key,
    required this.repo,
    required this.viewer,
    required this.bundle,
    required this.onReload,
    this.societyName,
  });

  final PollRepository repo;
  final PollViewer viewer;
  final PollsBundle bundle;
  final Future<void> Function() onReload;
  final String? societyName;

  @override
  State<ElectionSection> createState() => _ElectionSectionState();
}

class _ElectionSectionState extends State<ElectionSection> {
  bool _showForm = false;
  final _question = TextEditingController();
  final _description = TextEditingController();
  DateTime? _nomStart;
  DateTime? _nomEnd;
  DateTime? _voteStart;
  DateTime? _voteEnd;
  String _termFrom = '';
  String _termTo = '';
  final Map<String, List<TextEditingController>> _seeds = {
    for (final p in ElectionPosts.managementCommittee) p: [TextEditingController()],
  };
  bool _creating = false;

  /// pollId → ballot choices.
  final Map<String, Map<String, dynamic>> _ballotDraft = {};
  String? _nominatePollId;
  String? _nominatePost;
  final _statement = TextEditingController();
  String? _scheduleEditId;
  DateTime? _sNomStart;
  DateTime? _sNomEnd;
  DateTime? _sVoteStart;
  DateTime? _sVoteEnd;
  Map<String, String> _photos = const {};
  String _photoKey = '';
  final Set<String> _busyPolls = {};

  PollViewer get _v => widget.viewer;
  bool get _isResident => _v.isResident;
  bool get _hi => context.lang == AppLang.hi;
  String get _societyId => widget.repo.societyId;

  @override
  void initState() {
    super.initState();
    _statement.addListener(() => setState(() {}));
    _syncFromBundle();
  }

  @override
  void didUpdateWidget(covariant ElectionSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bundle != widget.bundle) _syncFromBundle();
  }

  @override
  void dispose() {
    _question.dispose();
    _description.dispose();
    _statement.dispose();
    for (final l in _seeds.values) {
      for (final c in l) {
        c.dispose();
      }
    }
    super.dispose();
  }

  void _syncFromBundle() {
    // Submitted ballots replace drafts (web merges `ballots` into `ballotDraft`).
    if (_v.voterId.isNotEmpty) {
      for (final b in widget.bundle.ballots) {
        if (b.voterId == _v.voterId && b.choices is Map) {
          _ballotDraft[b.pollId] = Map<String, dynamic>.from(b.choices as Map);
        }
      }
    }
    final ids = (widget.bundle.options.map((o) => o.memberId).whereType<String>().toSet().toList()..sort()).join(',');
    if (ids != _photoKey) {
      _photoKey = ids;
      if (ids.isEmpty) {
        _photos = const {};
      } else {
        GovBackend.fetchMemberPhotoMap(ids.split(',')).then((m) {
          if (mounted && _photoKey == ids) setState(() => _photos = m);
        });
      }
    }
  }

  String? _photoForOption(PollOptionRow o) => o.memberId == null ? null : _photos[o.memberId];

  Future<void> _run(String pollId, Future<void> Function() action) async {
    setState(() => _busyPolls.add(pollId));
    try {
      await action();
    } catch (e) {
      if (mounted) GovToast.error(context, GovBackend.errorText(e));
    } finally {
      if (mounted) setState(() => _busyPolls.remove(pollId));
    }
  }

  // ------------------------------------------------------------- create

  void _resetForm() {
    _question.clear();
    _description.clear();
    _nomStart = _nomEnd = _voteStart = _voteEnd = null;
    _termFrom = _termTo = '';
    for (final l in _seeds.values) {
      for (final c in l.skip(1)) {
        c.dispose();
      }
      l.removeRange(1, l.length);
      l.first.clear();
    }
  }

  Future<void> _create() async {
    if (_question.text.trim().isEmpty) return;
    if (_nomStart == null || _nomEnd == null || _voteStart == null || _voteEnd == null) {
      GovToast.error(context, context.tr('Set open and close dates for both nomination and voting.', 'नामांकन व मतदान दोनों की आरंभ व समाप्ति तिथि दें।'));
      return;
    }
    if (_nomEnd!.isBefore(_nomStart!)) {
      GovToast.error(context, context.tr('Nomination close must be after open.', 'नामांकन समाप्ति आरंभ के बाद होनी चाहिए।'));
      return;
    }
    if (_voteEnd!.isBefore(_voteStart!)) {
      GovToast.error(context, context.tr('Voting close must be after open.', 'मतदान समाप्ति आरंभ के बाद होनी चाहिए।'));
      return;
    }
    setState(() => _creating = true);
    try {
      final title = _question.text.trim();
      await widget.repo.createElection(
        question: title,
        description: _description.text,
        adminName: _v.adminName,
        nominationStarts: _nomStart!,
        nominationEnds: _nomEnd!,
        votingStarts: _voteStart!,
        votingEnds: _voteEnd!,
        termFrom: _termFrom,
        termTo: _termTo,
        seedCandidates: {for (final e in _seeds.entries) e.key: e.value.map((c) => c.text).toList()},
      );
      if (!mounted) return;
      _resetForm();
      setState(() => _showForm = false);
      GovToast.ok(context, context.tr('Election created — nomination phase', 'चुनाव बना — नामांकन चरण'));
      await widget.onReload();
      await widget.repo.notify(ElectionNotifyEvent.nominationOpen, createdBy: _v.adminName, electionTitle: title);
    } catch (e) {
      if (mounted) GovToast.error(context, GovBackend.errorText(e).isEmpty ? context.tr('Could not create election', 'चुनाव नहीं बन सका') : GovBackend.errorText(e));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  // ------------------------------------------------------------- schedule

  void _openSchedule(PollRow p) {
    setState(() {
      _scheduleEditId = p.id;
      _sNomStart = DateTime.tryParse(p.nominationStartsAt ?? '')?.toLocal();
      _sNomEnd = DateTime.tryParse(p.nominationEndsAt ?? '')?.toLocal();
      _sVoteStart = DateTime.tryParse(p.votingStartsAt ?? '')?.toLocal();
      _sVoteEnd = DateTime.tryParse(p.votingEndsAt ?? '')?.toLocal();
    });
  }

  Future<void> _saveSchedule(PollRow p) async {
    if (_sNomStart == null || _sNomEnd == null || _sVoteStart == null || _sVoteEnd == null) {
      GovToast.error(context, context.tr('All four dates are required.', 'चारों तिथियाँ आवश्यक हैं।'));
      return;
    }
    if (_sNomEnd!.isBefore(_sNomStart!) || _sVoteEnd!.isBefore(_sVoteStart!)) {
      GovToast.error(context, context.tr('Each close date must be after its open date.', 'प्रत्येक समाप्ति तिथि उसकी आरंभ तिथि के बाद होनी चाहिए।'));
      return;
    }
    await _run(p.id, () async {
      await widget.repo.updateSchedule(
        pollId: p.id,
        nominationStarts: _sNomStart!,
        nominationEnds: _sNomEnd!,
        votingStarts: _sVoteStart!,
        votingEnds: _sVoteEnd!,
      );
      if (!mounted) return;
      GovToast.ok(context, context.tr('Schedule updated', 'समय-सारिणी अद्यतन'));
      setState(() => _scheduleEditId = null);
      await widget.onReload();
    });
  }

  // ------------------------------------------------------------- nomination

  Future<void> _selfNominate(PollRow poll) async {
    final post = _nominatePost;
    if (post == null) return;
    if (_v.memberId.isEmpty || _v.memberName.isEmpty || _v.flatId.isEmpty) {
      GovToast.error(context, context.tr('Your member profile is required to self-nominate.', 'स्व-नामांकन हेतु आपकी सदस्य प्रोफ़ाइल आवश्यक है।'));
      return;
    }
    if (!isPostOpenForNomination(poll.raw, post)) {
      GovToast.error(context, context.tr('Self-nomination is not open for this post right now.', 'इस पद हेतु अभी स्व-नामांकन खुला नहीं है।'));
      return;
    }
    final statement = _statement.text.trim();
    if (statement.length < 20) {
      GovToast.error(
        context,
        context.tr('Please write at least a short statement (20+ characters) explaining why you should be chosen.',
            'कृपया कम-से-कम संक्षिप्त विवरण (20+ अक्षर) लिखें कि आपको क्यों चुना जाए।'),
      );
      return;
    }
    if (widget.bundle.options.any((o) => o.pollId == poll.id && o.electionPost == post && o.memberId == _v.memberId)) {
      GovToast.error(context, context.tr('You have already nominated yourself for this post.', 'आप इस पद हेतु पहले ही नामांकन कर चुके हैं।'));
      return;
    }
    await _run(poll.id, () async {
      final elig = await GovBackend.memberEligibility(memberId: _v.memberId, societyId: _societyId);
      if (!mounted) return;
      if (elig.error != null) {
        GovToast.error(context, elig.error!);
        return;
      }
      if (elig.data != null && !elig.data!.eligible) {
        final detail = elig.data!.reasons.map((r) => eligibilityReasonLabel(r, hi: _hi)).join('; ');
        GovToast.error(
          context,
          detail.isNotEmpty ? detail : context.tr('You are not eligible to contest under the bye-laws.', 'उपविधि के अनुसार आप चुनाव लड़ने के पात्र नहीं हैं।'),
        );
        return;
      }
      await widget.repo.insertNomination({
        'poll_id': poll.id,
        'option_text': _v.memberName.trim(),
        'election_post': post,
        'votes_count': 0,
        'member_id': _v.memberId,
        'flat_id': _v.flatId,
        'flat_number': _v.flatNumber.isEmpty ? null : _v.flatNumber,
        'nominated_by': _v.voterId.isNotEmpty ? _v.voterId : _v.memberId,
        'nomination_statement': statement,
      });
      await GovBackend.logElectionAudit(
        societyId: _societyId,
        pollId: poll.id,
        eventType: 'nomination_submitted',
        actorType: 'resident',
        actorId: _v.memberId,
        actorName: _v.memberName,
        payload: {'post': post},
      );
      if (!mounted) return;
      GovToast.ok(context, context.tr('Nominated for ${postDisplay(post)}', '${postDisplay(post, hi: true)} हेतु नामांकित'));
      setState(() {
        _nominatePost = null;
        _nominatePollId = null;
      });
      _statement.clear();
      await widget.onReload();
    });
  }

  // ------------------------------------------------------------- ballot

  void _toggleCombined(String pollId, String optionId) {
    setState(() {
      final cur = Map<String, dynamic>.from(_ballotDraft[pollId] ?? const {});
      final sel = asStringList(cur['selected']).toList();
      if (sel.contains(optionId)) {
        sel.remove(optionId);
      } else if (sel.length < ByeLaw.committeeSize) {
        sel.add(optionId);
      }
      cur['selected'] = sel;
      _ballotDraft[pollId] = cur;
    });
  }

  void _setOfficePick(String pollId, String post, String optionId) {
    setState(() {
      final cur = Map<String, dynamic>.from(_ballotDraft[pollId] ?? const {});
      if (post == ElectionPosts.committee) {
        final picks = asStringList(cur['committee']).toList();
        if (picks.contains(optionId)) {
          picks.remove(optionId);
        } else if (picks.length < ByeLaw.executiveMembers) {
          picks.add(optionId);
        }
        cur['committee'] = picks;
      } else {
        cur[post] = optionId;
      }
      _ballotDraft[pollId] = cur;
    });
  }

  Future<void> _submitBallot(PollRow poll) async {
    if (_v.voterId.isEmpty || _v.flatId.isEmpty) {
      GovToast.error(context, context.tr('Missing member or flat context.', 'सदस्य या फ्लैट जानकारी उपलब्ध नहीं।'));
      return;
    }
    if (!isVotingWindowOpen(poll.raw)) {
      GovToast.error(context, context.tr('Voting is not open in the current time window.', 'वर्तमान समय में मतदान खुला नहीं है।'));
      return;
    }
    if ((poll.votingMethod ?? '').isEmpty) {
      GovToast.error(context, context.tr('Voting method has not been recorded yet (Secret Ballot or Show of Hands).',
          'मतदान विधि अभी दर्ज नहीं हुई (गुप्त मतपत्र या हाथ उठाकर)।'));
      return;
    }
    final ballots = widget.bundle.ballotsFor(poll.id);
    if (ballots.any((b) => b.voterId == _v.voterId)) {
      GovToast.error(context, context.tr('Your ballot is already submitted and cannot be edited.', 'आपका मतपत्र पहले ही जमा है और संपादित नहीं हो सकता।'));
      return;
    }
    await _run(poll.id, () async {
      if (_v.memberId.isNotEmpty) {
        final elig = await GovBackend.memberEligibility(memberId: _v.memberId, societyId: _societyId);
        if (!mounted) return;
        if (elig.error != null) {
          GovToast.error(context, elig.error!);
          return;
        }
        if (elig.data != null && !elig.data!.eligible) {
          final detail = elig.data!.reasons.map((r) => eligibilityReasonLabel(r, hi: _hi)).join('; ');
          GovToast.error(context, detail.isNotEmpty ? detail : context.tr('You are not eligible to vote under the bye-laws.', 'उपविधि के अनुसार आप मतदान के पात्र नहीं हैं।'));
          await GovBackend.logElectionAudit(
            societyId: _societyId,
            pollId: poll.id,
            eventType: 'eligibility_checked',
            actorType: 'resident',
            actorId: _v.memberId,
            actorName: _v.memberName.isEmpty ? null : _v.memberName,
            payload: {'eligible': false, 'reasons': elig.data!.reasons, 'action': 'ballot'},
          );
          return;
        }
      }
      final opts = widget.bundle.optionsFor(poll.id).map((o) => o.tally).toList();
      final separate = poll.separateOfficeVotes;
      final choices = _ballotDraft[poll.id] ?? <String, dynamic>{};
      final err = validateElectionChoices(opts, choices, separate,
          committeeSeats: ByeLaw.executiveMembers, maxMarks: ByeLaw.committeeSize);
      if (err != null) {
        if (mounted) GovToast.error(context, err.text(_hi));
        return;
      }
      final phone = _v.voterPhone.replaceAll(RegExp(r'\D'), '');
      if (phone.isNotEmpty && ballots.any((b) => (b.voterPhone ?? '').replaceAll(RegExp(r'\D'), '') == phone)) {
        if (mounted) {
          GovToast.error(context, context.tr('You have already voted (one vote per member, even across multiple flats).',
              'आप पहले ही मतदान कर चुके हैं (प्रति सदस्य एक मत, कई फ्लैट होने पर भी)।'));
        }
        return;
      }
      try {
        await widget.repo.insertBallot({
          'poll_id': poll.id,
          'voter_id': _v.voterId,
          'flat_id': _v.flatId,
          'flat_number': _v.flatNumber.isEmpty ? null : _v.flatNumber,
          'voter_phone': phone.isEmpty ? null : phone,
          'rankings': <String, dynamic>{},
          'choices': choices,
          'ballot_method': poll.votingMethod,
          'is_proxy_vote': false,
          'submitted_at': jsIsoString(DateTime.now()),
        });
      } catch (e) {
        final msg = GovBackend.errorText(e);
        if (!mounted) return;
        if (RegExp('duplicate|unique', caseSensitive: false).hasMatch(msg)) {
          GovToast.error(context, context.tr('Duplicate vote blocked — one ballot per member.', 'दोहरा मत रोका गया — प्रति सदस्य एक मतपत्र।'));
        } else if (RegExp('immutable', caseSensitive: false).hasMatch(msg)) {
          GovToast.error(context, context.tr('Ballots cannot be changed after submission.', 'जमा होने के बाद मतपत्र बदले नहीं जा सकते।'));
        } else {
          GovToast.error(context, msg);
        }
        return;
      }
      await GovBackend.logElectionAudit(
        societyId: _societyId,
        pollId: poll.id,
        eventType: 'ballot_cast',
        actorType: 'resident',
        actorId: _v.memberId.isNotEmpty ? _v.memberId : _v.voterId,
        actorName: _v.memberName.isEmpty ? null : _v.memberName,
        payload: {'ballot_method': poll.votingMethod, 'separate_office_votes': separate, 'voter_id': _v.voterId},
      );
      if (!mounted) return;
      GovToast.ok(context, context.tr('Ballot submitted (final — cannot be edited)', 'मतपत्र जमा (अंतिम — संपादित नहीं हो सकता)'));
      await widget.onReload();
    });
  }

  // ------------------------------------------------------------- admin phases

  Future<void> _startVoting(PollRow poll) async {
    if ((poll.votingMethod ?? '').isEmpty) {
      GovToast.error(context, context.tr('Record the voting method (Secret Ballot or Show of Hands) before opening the poll.',
          'मतदान खोलने से पहले मतदान विधि (गुप्त मतपत्र या हाथ उठाकर) दर्ज करें।'));
      return;
    }
    final ok = await govConfirm(
      context,
      title: context.tr('Open voting?', 'मतदान खोलें?'),
      message: context.tr(
          'Method: ${votingMethodShortLabel(poll.votingMethod)}. Residents cast one vote each during the scheduled window. Quorum is 3/4 of members.',
          'विधि: ${votingMethodShortLabel(poll.votingMethod, hi: true)}। निवासी निर्धारित अवधि में एक-एक मत डालेंगे। कोरम सदस्यों का 3/4 है।'),
      confirmLabel: context.tr('Open voting', 'मतदान खोलें'),
    );
    if (!ok) return;
    await _run(poll.id, () async {
      final memberCount = await GovBackend.activeMemberCount(_societyId);
      final quorum = memberCount == null ? null : electionQuorumRequired(memberCount);
      await widget.repo.patchPoll(poll.id, {
        'election_phase': 'voting',
        'is_active': true,
        if (memberCount != null) 'member_count_at_election': memberCount,
        if (memberCount != null) 'election_quorum_required': quorum,
      });
      await GovBackend.logElectionAudit(
        societyId: _societyId,
        pollId: poll.id,
        eventType: 'phase_changed',
        actorType: 'admin',
        actorName: _v.adminName,
        payload: {
          'to': 'voting',
          'voting_method': poll.votingMethod,
          'member_count_at_election': memberCount,
          'election_quorum_required': quorum,
          'bye_law_quorum_example_30': ByeLaw.electionQuorumFor30,
        },
      );
      if (!mounted) return;
      GovToast.ok(
        context,
        quorum != null
            ? context.tr('Voting open — quorum $quorum of $memberCount members (3/4)', 'मतदान खुला — कोरम $memberCount में से $quorum सदस्य (3/4)')
            : context.tr('Voting phase started', 'मतदान चरण आरंभ'),
      );
      await widget.onReload();
      await widget.repo.notify(ElectionNotifyEvent.votingOpen, createdBy: _v.adminName, electionTitle: poll.question);
    });
  }

  Future<void> _closeElection(PollRow poll) async {
    final ballots = widget.bundle.ballotsFor(poll.id);
    final quorum = poll.electionQuorumRequired;
    final memberCount = poll.memberCountAtElection;
    final quorumNote = quorum != null
        ? context.tr(' Ballots cast: ${ballots.length}${memberCount != null ? ' · quorum $quorum of $memberCount' : ''}.',
            ' डाले गए मतपत्र: ${ballots.length}${memberCount != null ? ' · कोरम $memberCount में से $quorum' : ''}।')
        : '';
    if (quorum != null && ballots.length < quorum) {
      final proceed = await govConfirm(
        context,
        title: context.tr('Quorum not met', 'कोरम पूरा नहीं'),
        message: context.tr(
            'Only ${ballots.length} ballot(s) vs required quorum $quorum. Close and tally anyway? Election may be invalid under bye-laws.',
            'केवल ${ballots.length} मतपत्र, आवश्यक कोरम $quorum। फिर भी बंद कर गिनती करें? उपविधि के अनुसार चुनाव अमान्य हो सकता है।'),
        confirmLabel: context.tr('Close anyway', 'फिर भी बंद करें'),
        destructive: true,
      );
      if (!proceed) return;
    } else {
      if (!mounted) return;
      final ok = await govConfirm(
        context,
        title: context.tr('Close election?', 'चुनाव बंद करें?'),
        message: context.tr(
            'Voting stops. Results stay in the admin portal until you publish the seven-member Management Committee.$quorumNote Second- or third-place candidates are not automatically seated.',
            'मतदान रुकेगा। सात-सदस्यीय प्रबंध समिति प्रकाशित करने तक परिणाम प्रशासक पोर्टल में रहेंगे।$quorumNote द्वितीय या तृतीय स्थान वाले स्वतः नहीं बैठाए जाते।'),
        confirmLabel: context.tr('Close & tally', 'बंद करें व गिनें'),
      );
      if (!ok) return;
    }
    await _run(poll.id, () async {
      final results = widget.repo.tally(poll, widget.bundle.optionsFor(poll.id), ballots);
      final deadline = utcIsoDate(DateTime.now().add(const Duration(days: ByeLaw.firstMeetingWithinDays)));
      await widget.repo.patchPoll(poll.id, {
        'is_active': false,
        'election_phase': 'closed',
        'election_results': results,
        'first_mc_meeting_deadline': deadline,
      });
      await GovBackend.logElectionAudit(
        societyId: _societyId,
        pollId: poll.id,
        eventType: 'election_tallied',
        actorType: 'admin',
        actorName: _v.adminName,
        payload: {
          'ballot_count': ballots.length,
          'quorum_required': quorum,
          'quorum_met': quorum == null ? null : ballots.length >= quorum,
          'ballot_mode': results['ballot_mode'],
        },
      );
      if (!mounted) return;
      await AppFeedback.success(context,
          title: context.tr('Election closed', 'चुनाव बंद'),
          message: context.tr('Results are available here in the admin portal.', 'परिणाम यहाँ प्रशासक पोर्टल में उपलब्ध हैं।'));
      await widget.onReload();
      await widget.repo.notify(ElectionNotifyEvent.electionClosed, createdBy: _v.adminName, electionTitle: poll.question);
    });
  }

  Future<void> _publish(PollRow poll) async {
    final results = poll.electionResults;
    if (results == null) return;
    final formed = countFormedCommittee(results);
    final target = poll.targetCommitteeSize;
    if (formed < minCommitteeSize) {
      GovToast.error(
        context,
        context.tr(
            'Bye-laws require $minCommitteeSize Management Committee members before publishing (currently $formed). Fill vacant seats per the vacancy procedure — do not auto-seat runners-up.',
            'प्रकाशन से पहले उपविधि के अनुसार $minCommitteeSize प्रबंध समिति सदस्य आवश्यक (अभी $formed)। रिक्त पद रिक्ति प्रक्रिया से भरें — उपविजेताओं को स्वतः न बैठाएँ।'),
      );
      return;
    }
    final ok = await govConfirm(
      context,
      title: context.tr('Publish Management Committee?', 'प्रबंध समिति प्रकाशित करें?'),
      message: formed < target
          ? context.tr('Roster has $formed members (required $target). Publish the elected seven-member Management Committee to the Committee tab?',
              'सूची में $formed सदस्य (आवश्यक $target)। निर्वाचित सात-सदस्यीय प्रबंध समिति समिति टैब में प्रकाशित करें?')
          : context.tr('Publish $formed members of the Management Committee to the Committee tab? All members will be notified.',
              'प्रबंध समिति के $formed सदस्य समिति टैब में प्रकाशित करें? सभी सदस्यों को सूचित किया जाएगा।'),
      confirmLabel: context.tr('Publish', 'प्रकाशित करें'),
    );
    if (!ok) return;
    await _run(poll.id, () async {
      final err = await widget.repo.applyElectionToCommittee(
        pollId: poll.id,
        results: results,
        options: widget.bundle.optionsFor(poll.id),
        termFrom: poll.electionTermFrom,
        termTo: poll.electionTermTo,
      );
      if (!mounted) return;
      if (err != null) {
        GovToast.error(context, err);
        return;
      }
      await GovBackend.logElectionAudit(
        societyId: _societyId,
        pollId: poll.id,
        eventType: 'committee_published',
        actorType: 'admin',
        actorName: _v.adminName,
        payload: {'formed': formed, 'target': target},
      );
      if (!mounted) return;
      await AppFeedback.success(context,
          title: context.tr('Published', 'प्रकाशित'), message: context.tr('Committee roster updated for residents.', 'निवासियों हेतु समिति सूची अद्यतन।'));
      await widget.onReload();
      await widget.repo.notify(ElectionNotifyEvent.winnersPublished, createdBy: _v.adminName, electionTitle: poll.question);
    });
  }

  // ================================================================ UI

  Widget _nomineeInfo(PollOptionRow o, {bool statement = true}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(children: [
              TextSpan(text: o.optionText, style: const TextStyle(fontWeight: FontWeight.w500)),
              if ((o.flatNumber ?? '').isNotEmpty) TextSpan(text: '  · ${context.tr('Flat', 'फ्लैट')} ${o.flatNumber}', style: AppText.tiny(context)),
            ]),
            style: const TextStyle(fontSize: 13),
          ),
          if (statement && (o.nominationStatement ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(o.nominationStatement!, style: AppText.caption(context).copyWith(fontSize: 11)),
            ),
        ],
      );

  Widget _candidateList(PollRow poll, String post) {
    final t = context.tokens;
    final opts = widget.bundle.optionsFor(poll.id).where((o) => o.electionPost == post).toList();
    if (opts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${postDisplay(post, hi: _hi)} — ${context.tr('nominees', 'नामांकित')}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.mutedForeground)),
          const SizedBox(height: 6),
          for (final o in opts)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTokens.tint(t.muted, 0.3),
                border: Border.all(color: AppTokens.tint(t.border, 0.6)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: PersonPhotoSide(name: o.optionText, photo: _photoForOption(o), child: _nomineeInfo(o)),
            ),
        ],
      ),
    );
  }

  Widget _ballotControls(PollRow poll) {
    final t = context.tokens;
    final opts = widget.bundle.optionsFor(poll.id);
    final draft = _ballotDraft[poll.id] ?? const <String, dynamic>{};
    Widget option(PollOptionRow o, {required bool checked, required bool radio, required VoidCallback onTap, bool statement = true}) =>
        InkWell(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: checked ? AppTokens.tint(t.primary, 0.05) : null,
              border: Border.all(color: checked ? t.primary : AppTokens.tint(t.border, 0.6)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  radio
                      ? (checked ? Icons.radio_button_checked : Icons.radio_button_unchecked)
                      : (checked ? Icons.check_box : Icons.check_box_outline_blank),
                  size: 20,
                  color: checked ? t.primary : t.mutedForeground,
                ),
                const SizedBox(width: 8),
                Expanded(child: PersonPhotoSide(name: o.optionText, photo: _photoForOption(o), child: _nomineeInfo(o, statement: statement))),
              ],
            ),
          ),
        );
    if (!poll.separateOfficeVotes) {
      final selected = asStringList(draft['selected']).toSet();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('Mark up to ${ByeLaw.committeeSize} nominees (one ballot per member — not ranked)',
                'अधिकतम ${ByeLaw.committeeSize} नामांकितों को चिह्नित करें (प्रति सदस्य एक मतपत्र — क्रमांकित नहीं)'),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.mutedForeground),
          ),
          Text(
            context.tr('Selected ${selected.length} / ${ByeLaw.committeeSize}. Highest marks fill each nominated post.',
                'चयनित ${selected.length} / ${ByeLaw.committeeSize}। सर्वाधिक अंक वाले प्रत्येक पद को भरते हैं।'),
            style: AppText.caption(context).copyWith(fontSize: 11),
          ),
          const SizedBox(height: 8),
          for (final post in ElectionPosts.managementCommittee)
            if (opts.any((o) => o.electionPost == post)) ...[
              Text(postDisplay(post, hi: _hi), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              for (final o in opts.where((o) => o.electionPost == post))
                option(o, checked: selected.contains(o.id), radio: false, onTap: () => _toggleCombined(poll.id, o.id)),
            ],
        ],
      );
    }
    final committeePicks = asStringList(draft['committee']).toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.tr('Separate office votes (expressly approved) — pick one per post (not ranked)',
              'प्रति-पद मत (स्पष्ट अनुमोदित) — प्रत्येक पद हेतु एक चुनें (क्रमांकित नहीं)'),
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.mutedForeground),
        ),
        const SizedBox(height: 8),
        for (final post in ElectionPosts.managementCommittee)
          if (opts.any((o) => o.electionPost == post)) ...[
            Text(
              '${postDisplay(post, hi: _hi)}${post == ElectionPosts.committee ? ' (${context.tr('up to', 'अधिकतम')} ${ByeLaw.executiveMembers})' : ''}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            for (final o in opts.where((o) => o.electionPost == post))
              option(
                o,
                checked: post == ElectionPosts.committee ? committeePicks.contains(o.id) : draft[post] == o.id,
                radio: post != ElectionPosts.committee,
                statement: false,
                onTap: () => _setOfficePick(poll.id, post, o.id),
              ),
          ],
      ],
    );
  }

  Widget _scheduleEditor(PollRow poll) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: context.tokens.border), borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.tr('SCHEDULE', 'समय-सारिणी'), style: AppText.fieldLabel(context)),
          const SizedBox(height: 8),
          GovDateTimeField(label: context.tr('Nomination opens', 'नामांकन आरंभ'), value: _sNomStart, onChanged: (v) => setState(() => _sNomStart = v)),
          const SizedBox(height: 8),
          GovDateTimeField(label: context.tr('Nomination closes', 'नामांकन समाप्त'), value: _sNomEnd, onChanged: (v) => setState(() => _sNomEnd = v)),
          const SizedBox(height: 8),
          GovDateTimeField(label: context.tr('Voting opens', 'मतदान आरंभ'), value: _sVoteStart, onChanged: (v) => setState(() => _sVoteStart = v)),
          const SizedBox(height: 8),
          GovDateTimeField(label: context.tr('Voting closes', 'मतदान समाप्त'), value: _sVoteEnd, onChanged: (v) => setState(() => _sVoteEnd = v)),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: MiniButton(
              label: context.tr('Save schedule', 'समय-सारिणी सहेजें'),
              variant: MiniVariant.primary,
              busy: _busyPolls.contains(poll.id),
              onPressed: () => _saveSchedule(poll),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(PollRow poll) {
    final t = context.tokens;
    final phase = poll.phase;
    final ballots = widget.bundle.ballotsFor(poll.id);
    final myBallot = ballots.where((b) => b.voterId == _v.voterId && _v.voterId.isNotEmpty).firstOrNull;
    final votingOpen = isVotingWindowOpen(poll.raw);
    final nominationOpen = isNominationWindowOpen(poll.raw);
    final opts = widget.bundle.optionsFor(poll.id);
    final posts = postsForPoll(poll.raw, opts.map((o) => o.electionPost));
    final editingSchedule = _scheduleEditId == poll.id;
    final busy = _busyPolls.contains(poll.id);
    final results = ElectionResults.tryParse(poll.electionResultsRaw);
    final optById = {for (final o in opts) o.id: o};

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(AppTokens.radius),
        border: Border.all(color: t.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(border: Border(left: BorderSide(color: t.primary, width: 4))),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${context.tr('ELECTION', 'चुनाव')} · ${ByeLaw.committeeSize}-${context.tr('MEMBER MC', 'सदस्यीय प्रबंध समिति')}',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: t.primary),
                      ),
                      Text(poll.question, style: AppText.sectionTitle(context)),
                      if ((poll.description ?? '').isNotEmpty)
                        Padding(padding: const EdgeInsets.only(top: 4), child: Text(poll.description!, style: AppText.caption(context))),
                      const SizedBox(height: 4),
                      Text('${context.tr('Nomination', 'नामांकन')}: ${nominationWindowLabel(poll.raw, hi: _hi)}', style: AppText.tiny(context).copyWith(fontSize: 11)),
                      Text('${context.tr('Voting', 'मतदान')}: ${votingWindowLabel(poll.raw, hi: _hi)}', style: AppText.tiny(context).copyWith(fontSize: 11)),
                      if (!_isResident && poll.electionQuorumRequired != null)
                        Text(
                          '${context.tr('Quorum', 'कोरम')} ${poll.electionQuorumRequired}${poll.memberCountAtElection != null ? ' ${context.tr('of', 'में से')} ${poll.memberCountAtElection}' : ''} (3/4)',
                          style: AppText.tiny(context).copyWith(fontSize: 11),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusBadge(phaseBadgeLabel(phase, hi: _hi)),
              ],
            ),
            const SizedBox(height: 6),
            Text(context.tr('${ballots.length} ballot(s) cast', '${ballots.length} मतपत्र डाले गए'), style: AppText.caption(context)),
            if ((phase == ElectionPhase.closed || phase == ElectionPhase.applied) && results != null)
              TintBox(
                color: t.primary,
                margin: const EdgeInsets.only(top: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.emoji_events_outlined, size: 14, color: t.primary),
                        const SizedBox(width: 4),
                        Text(
                          (!_isResident ? context.tr('Tallied results (admin only)', 'गिने गए परिणाम (केवल प्रशासक)') : context.tr('Results', 'परिणाम')).toUpperCase(),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: t.primary, letterSpacing: 0.4),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ElectionResultsBlock(
                      results: results,
                      photoForOption: (oid) => optById[oid] == null ? null : _photoForOption(optById[oid]!),
                    ),
                  ],
                ),
              ),
            if (phase == ElectionPhase.closed && results != null)
              CommitteeFormationPanel(poll: poll, repo: widget.repo, viewer: _v, photoByMemberId: _photos, onReload: widget.onReload),
            if (phase == ElectionPhase.nomination || phase == ElectionPhase.voting) ...[
              const SizedBox(height: 10),
              for (final post in ElectionPosts.managementCommittee.where(posts.contains)) _candidateList(poll, post),
            ],
            if (_isResident && phase == ElectionPhase.nomination)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: t.border))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!nominationOpen)
                      Text(
                        '${context.tr('Nomination opens in the scheduled window', 'नामांकन निर्धारित अवधि में खुलेगा')}: ${nominationWindowLabel(poll.raw, hi: _hi)}',
                        style: TextStyle(fontSize: 12, color: t.warning),
                      )
                    else ...[
                      Text(context.tr('Propose yourself for a post', 'स्वयं को किसी पद हेतु प्रस्तावित करें'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final post in ElectionPosts.managementCommittee)
                            if (isPostOpenForNomination(poll.raw, post))
                              MiniButton(
                                label: postDisplay(post, hi: _hi),
                                icon: Icons.person_add_alt_1_outlined,
                                onPressed: () => setState(() {
                                  _nominatePollId = poll.id;
                                  _nominatePost = post;
                                  _statement.clear();
                                }),
                              ),
                        ],
                      ),
                      if (_nominatePollId == poll.id && _nominatePost != null)
                        TintBox(
                          color: t.primary,
                          margin: const EdgeInsets.only(top: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                context.tr('Nominate for ${postDisplay(_nominatePost!)} — why should members prefer you?',
                                    '${postDisplay(_nominatePost!, hi: true)} हेतु नामांकन — सदस्य आपको क्यों चुनें?'),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              AppTextField(
                                controller: _statement,
                                hint: context.tr('Write why you should be chosen…', 'लिखें कि आपको क्यों चुना जाए…'),
                                maxLines: 6,
                                minLines: 4,
                                maxLength: 2000,
                                caps: false,
                              ),
                              Text('${_statement.text.trim().length}/2000', style: AppText.tiny(context)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  MiniButton(
                                    label: context.tr('Submit nomination', 'नामांकन जमा करें'),
                                    variant: MiniVariant.primary,
                                    busy: busy,
                                    onPressed: () => _selfNominate(poll),
                                  ),
                                  const SizedBox(width: 8),
                                  LinkText(
                                    context.tr('Cancel', 'रद्द करें'),
                                    color: t.mutedForeground,
                                    onTap: () => setState(() {
                                      _nominatePost = null;
                                      _nominatePollId = null;
                                    }),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            if (_isResident && phase == ElectionPhase.voting)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: t.border))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!votingOpen)
                      Text('${context.tr('Voting opens in the scheduled window', 'मतदान निर्धारित अवधि में खुलेगा')}: ${votingWindowLabel(poll.raw, hi: _hi)}',
                          style: TextStyle(fontSize: 12, color: t.warning)),
                    if (myBallot != null && votingOpen)
                      Text(context.tr('Ballot submitted — final (cannot be edited).', 'मतपत्र जमा — अंतिम (संपादित नहीं हो सकता)।'),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: t.success)),
                    if (votingOpen && myBallot == null) ...[
                      Text(
                        '${context.tr('One vote per eligible member. Votes are final after submission.', 'प्रति पात्र सदस्य एक मत। जमा होने के बाद मत अंतिम है।')}${(poll.votingMethod ?? '').isNotEmpty ? ' ${context.tr('Method', 'विधि')}: ${votingMethodShortLabel(poll.votingMethod, hi: _hi)}.' : ' ${context.tr('Voting method not yet recorded by admin.', 'प्रशासक ने अभी मतदान विधि दर्ज नहीं की।')}'}',
                        style: AppText.caption(context),
                      ),
                      const SizedBox(height: 8),
                      _ballotControls(poll),
                      const SizedBox(height: 8),
                      AppButton(
                        label: context.tr('Submit ballot (final)', 'मतपत्र जमा करें (अंतिम)'),
                        loading: busy,
                        onPressed: _v.flatId.isEmpty || _v.voterId.isEmpty || (poll.votingMethod ?? '').isEmpty ? null : () => _submitBallot(poll),
                      ),
                    ],
                  ],
                ),
              ),
            PollDocumentsPanel(
              pollId: poll.id,
              repo: widget.repo,
              isAdmin: !_isResident,
              documents: widget.bundle.documents,
              createdBy: _v.adminName,
              onChanged: widget.onReload,
            ),
            if (!_isResident && ballots.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  children: [
                    for (final b in ballots.take(6))
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.bundle.voterProfiles[b.voterId]?.name ?? (b.voterId.length > 8 ? b.voterId.substring(0, 8) : b.voterId),
                              style: AppText.caption(context),
                            ),
                          ),
                          Text(
                            '${context.tr('Flat', 'फ्लैट')} ${widget.bundle.voterProfiles[b.voterId]?.flatNumber ?? b.flatNumber ?? '—'}',
                            style: AppText.caption(context),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            VotingMethodConsentPanel(poll: poll, repo: widget.repo, viewer: _v, onReload: widget.onReload),
            if (!_isResident)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (phase == ElectionPhase.nomination || phase == ElectionPhase.voting)
                      MiniButton(
                        label: editingSchedule ? context.tr('Hide schedule', 'समय-सारिणी छिपाएँ') : context.tr('Edit dates', 'तिथियाँ संपादित करें'),
                        icon: Icons.edit_calendar_outlined,
                        onPressed: () => editingSchedule ? setState(() => _scheduleEditId = null) : _openSchedule(poll),
                      ),
                    if (phase == ElectionPhase.nomination)
                      MiniButton(
                        label: context.tr('Start voting window', 'मतदान अवधि आरंभ करें'),
                        variant: MiniVariant.primary,
                        busy: busy,
                        onPressed: () => _startVoting(poll),
                      ),
                    if (phase == ElectionPhase.voting && poll.isActive)
                      LinkText(context.tr('Close election & tally', 'चुनाव बंद करें व गिनें'), color: t.destructive, onTap: busy ? null : () => _closeElection(poll)),
                    if (phase == ElectionPhase.closed)
                      MiniButton(
                        label: context.tr('Publish formed Committee to roster', 'गठित समिति सूची में प्रकाशित करें'),
                        variant: MiniVariant.success,
                        busy: busy,
                        onPressed: () => _publish(poll),
                      ),
                    if (phase == ElectionPhase.applied)
                      Text('✓ ${context.tr('Published to committee roster', 'समिति सूची में प्रकाशित')}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: t.success)),
                  ],
                ),
              ),
            if (!_isResident && editingSchedule) _scheduleEditor(poll),
          ],
        ),
      ),
    );
  }

  Widget _createForm() {
    const gap = SizedBox(height: 10);
    return CardSection(
      margin: const EdgeInsets.only(bottom: 16, top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('SOCIETY ELECTION — 7-MEMBER MANAGEMENT COMMITTEE (NOMINATION FIRST)', 'सोसायटी चुनाव — 7-सदस्यीय प्रबंध समिति (पहले नामांकन)'),
            style: AppText.fieldLabel(context),
          ),
          gap,
          AppTextField(controller: _question, hint: context.tr('Election title (e.g. Managing Committee 2026)', 'चुनाव शीर्षक (जैसे प्रबंध समिति 2026)')),
          gap,
          AppTextField(controller: _description, hint: context.tr('Description (optional)', 'विवरण (वैकल्पिक)'), maxLines: 3, minLines: 2),
          gap,
          Text(context.tr('Nomination window', 'नामांकन अवधि'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          GovDateTimeField(label: context.tr('Opens', 'आरंभ'), value: _nomStart, onChanged: (v) => setState(() => _nomStart = v)),
          const SizedBox(height: 6),
          GovDateTimeField(label: context.tr('Closes', 'समाप्त'), value: _nomEnd, onChanged: (v) => setState(() => _nomEnd = v)),
          gap,
          Text(context.tr('Voting window', 'मतदान अवधि'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          GovDateTimeField(label: context.tr('Opens', 'आरंभ'), value: _voteStart, onChanged: (v) => setState(() => _voteStart = v)),
          const SizedBox(height: 6),
          GovDateTimeField(label: context.tr('Closes', 'समाप्त'), value: _voteEnd, onChanged: (v) => setState(() => _voteEnd = v)),
          gap,
          Row(
            children: [
              Expanded(child: GovDateField(label: context.tr('Tenure from', 'कार्यकाल से'), value: _termFrom, onChanged: (v) => setState(() => _termFrom = v))),
              const SizedBox(width: 8),
              Expanded(child: GovDateField(label: context.tr('Tenure to (optional)', 'कार्यकाल तक (वैकल्पिक)'), value: _termTo, onChanged: (v) => setState(() => _termTo = v))),
            ],
          ),
          gap,
          for (final post in ElectionPosts.managementCommittee) ...[
            Text('${postDisplay(post, hi: _hi)} — ${context.tr('seed candidates (optional)', 'प्रारंभिक अभ्यर्थी (वैकल्पिक)')}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            for (final (i, c) in _seeds[post]!.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(child: AppTextField(controller: c, hint: '${context.tr('Name', 'नाम')} ${i + 1}', caps: false)),
                    if (_seeds[post]!.length > 1)
                      IconButton(
                        onPressed: () => setState(() => _seeds[post]!.removeAt(i).dispose()),
                        icon: Icon(Icons.delete_outline, size: 18, color: context.tokens.destructive),
                      ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: LinkText(
                '+ ${context.tr('Add', 'जोड़ें')} ${postDisplay(post, hi: _hi)} ${context.tr('candidate', 'अभ्यर्थी')}',
                onTap: () => setState(() => _seeds[post]!.add(TextEditingController())),
              ),
            ),
            const SizedBox(height: 8),
          ],
          AppButton(label: context.tr('Create election (nomination phase)', 'चुनाव बनाएँ (नामांकन चरण)'), loading: _creating, onPressed: _create),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final elections = widget.bundle.electionPolls;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VotingCharterPanel(societyId: _societyId, societyName: widget.societyName, isAdmin: !_isResident),
        if (!_isResident) ...[
          AppButton(
            label: context.tr('New society election', 'नया सोसायटी चुनाव'),
            icon: Icons.account_balance_outlined,
            onPressed: () => setState(() => _showForm = !_showForm),
          ),
          if (_showForm) _createForm() else const SizedBox(height: 12),
        ],
        if (elections.isEmpty)
          CardSection(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(Icons.account_balance_outlined, size: 32, color: AppTokens.tint(t.mutedForeground, 0.5)),
                const SizedBox(height: 8),
                Text(context.tr('No society elections yet.', 'अभी कोई सोसायटी चुनाव नहीं।'), style: AppText.body(context).copyWith(color: t.mutedForeground)),
                const SizedBox(height: 4),
                Text(
                  _isResident
                      ? context.tr('When the admin opens an election, you can self-nominate and vote here.', 'प्रशासक द्वारा चुनाव खोलने पर आप यहाँ स्व-नामांकन व मतदान कर सकते हैं।')
                      : context.tr('Create an election to open nomination for the seven-member Management Committee.', 'सात-सदस्यीय प्रबंध समिति हेतु नामांकन खोलने के लिए चुनाव बनाएँ।'),
                  textAlign: TextAlign.center,
                  style: AppText.caption(context),
                ),
              ],
            ),
          )
        else
          for (final p in elections) _card(p),
      ],
    );
  }
}
