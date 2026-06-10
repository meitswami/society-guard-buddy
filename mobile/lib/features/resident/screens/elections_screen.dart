import 'package:flutter/material.dart';

import '../../../core/theme/kutumbika_brand_theme.dart';
import '../../../core/theme/kutumbika_colors.dart';
import '../../../models/session_models.dart';
import '../../../services/election_service.dart';
import '../../../services/member_service.dart';
import '../../../utils/election_governance.dart';
import '../../../utils/election_validation.dart';

class ElectionsScreen extends StatefulWidget {
  const ElectionsScreen({super.key, required this.session});

  final SessionResident session;

  @override
  State<ElectionsScreen> createState() => _ElectionsScreenState();
}

class _ElectionsScreenState extends State<ElectionsScreen> {
  final _electionService = ElectionService();
  final _memberService = MemberService();
  ElectionBundle? _bundle;
  String? _voterMemberId;
  final _rankings = <String, Map<String, Map<String, int>>>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final member = await _memberService.findByPhone(
      widget.session.resident.flatId,
      widget.session.resident.phone,
    );
    final bundle = await _electionService.fetchForSociety(widget.session.societyId);
    if (!mounted) return;

    final ranks = <String, Map<String, Map<String, int>>>{};
    if (member != null) {
      for (final b in bundle.ballots) {
        if (b['voter_id'] == member.id && b['rankings'] is Map) {
          final raw = Map<String, dynamic>.from(b['rankings'] as Map);
          ranks[b['poll_id'] as String] = raw.map((post, opts) {
            final om = Map<String, dynamic>.from(opts as Map);
            return MapEntry(post, om.map((k, v) => MapEntry(k, (v as num).toInt())));
          });
        }
      }
    }

    setState(() {
      _voterMemberId = member?.id;
      _bundle = bundle;
      _rankings
        ..clear()
        ..addAll(ranks);
      _loading = false;
    });
  }

  Future<void> _selfNominate(String pollId, String post, Map<String, dynamic> raw) async {
    final memberId = _voterMemberId;
    if (memberId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link your phone to a household member to nominate')),
      );
      return;
    }
    if (!isPostOpenForNomination(raw, post)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Self-nomination is not open for this post')),
      );
      return;
    }

    try {
      await _electionService.selfNominate(
        pollId: pollId,
        post: post,
        memberId: memberId,
        memberName: widget.session.resident.name,
        flatId: widget.session.resident.flatId,
        flatNumber: widget.session.resident.flatNumber,
        nominatedBy: widget.session.resident.id,
        existingOptions: _bundle!.options,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nominated for ${postDisplay[post] ?? post}')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
      );
    }
  }

  Future<void> _submit(String pollId) async {
    final voterId = _voterMemberId;
    if (voterId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link your phone to a household member to vote')),
      );
      return;
    }

    final pollRaw = await _electionService.fetchPollRaw(pollId);
    if (pollRaw == null || !isVotingWindowOpen(pollRaw)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voting is not open')),
      );
      return;
    }

    final options = _bundle!.options.where((o) => o['poll_id'] == pollId).toList();
    final rankings = _rankings[pollId] ?? {};
    final err = validateElectionRankings(options, rankings);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }

    try {
      await _electionService.submitBallot(
        pollId: pollId,
        voterId: voterId,
        flatId: widget.session.resident.flatId,
        flatNumber: widget.session.resident.flatNumber,
        voterPhone: widget.session.resident.phone,
        rankings: rankings,
        existingBallots: _bundle!.ballots,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ballot submitted')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
      );
    }
  }

  void _setRank(String pollId, String post, String optionId, int? rank) {
    setState(() {
      final pollR = Map<String, Map<String, int>>.from(_rankings[pollId] ?? {});
      final postR = Map<String, int>.from(pollR[post] ?? {});
      if (rank == null) {
        postR.remove(optionId);
      } else {
        postR[optionId] = rank;
      }
      pollR[post] = postR;
      _rankings[pollId] = pollR;
    });
  }

  @override
  Widget build(BuildContext context) {
    final brand = KutumbikaBrandTheme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Society elections')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _buildList(brand),
            ),
    );
  }

  Widget _buildList(KutumbikaBrandTheme brand) {
    final bundle = _bundle!;
    if (bundle.elections.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(child: Text('No elections', style: TextStyle(color: KutumbikaColors.textMuted))),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bundle.elections.length,
      itemBuilder: (context, index) {
        final poll = bundle.elections[index];
        return FutureBuilder<Map<String, dynamic>?>(
          future: _electionService.fetchPollRaw(poll.id),
          builder: (context, snap) {
            final raw = snap.data;
            final open = raw != null && isVotingWindowOpen(raw);
            final phase = raw != null ? electionPhase(raw) : ElectionPhase.closed;
            final opts = bundle.options.where((o) => o['poll_id'] == poll.id).toList();
            final postsFromOpts = opts.map((o) => o['election_post'] as String?).whereType<String>().toSet();
            final posts = phase == ElectionPhase.nomination
                ? allElectionPosts.where((p) => raw != null && isPostOpenForNomination(raw, p)).toList()
                : postsFromOpts.toList();

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(poll.question, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    Text(
                      '${phaseBadgeLabel(phase)}${open ? ' · vote now' : ''}',
                      style: const TextStyle(fontSize: 12, color: KutumbikaColors.textMuted),
                    ),
                    if (raw != null && phase != ElectionPhase.nomination)
                      Text(
                        votingWindowLabel(raw),
                        style: const TextStyle(fontSize: 11, color: KutumbikaColors.textMuted),
                      ),
                    const SizedBox(height: 12),
                    if (phase == ElectionPhase.nomination)
                      for (final post in posts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(postDisplay[post] ?? post,
                                    style: TextStyle(fontWeight: FontWeight.w600, color: brand.primary)),
                              ),
                              TextButton.icon(
                                onPressed: raw == null ? null : () => _selfNominate(poll.id, post, raw),
                                icon: const Icon(Icons.person_add_outlined, size: 18),
                                label: const Text('Nominate me'),
                              ),
                            ],
                          ),
                        ),
                    if (phase == ElectionPhase.nomination && opts.isNotEmpty) ...[
                      const Divider(),
                      const Text('Current candidates', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      ...opts.map((o) => Text(
                            '· ${o['option_text']} (${postDisplay[o['election_post']] ?? o['election_post']})',
                            style: const TextStyle(fontSize: 12),
                          )),
                      const SizedBox(height: 12),
                    ],
                    if (phase == ElectionPhase.voting)
                      for (final post in posts) ...[
                      Text(postDisplay[post] ?? post, style: TextStyle(fontWeight: FontWeight.w600, color: brand.primary)),
                      const SizedBox(height: 6),
                      ...opts.where((o) => o['election_post'] == post).map((o) {
                        final id = o['id'] as String;
                        final m = opts.where((x) => x['election_post'] == post).length;
                        final current = _rankings[poll.id]?[post]?[id];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Expanded(child: Text(o['option_text'] as String? ?? '')),
                              SizedBox(
                                width: 72,
                                child: DropdownButtonFormField<int>(
                                  initialValue: current,
                                  decoration: const InputDecoration(isDense: true, labelText: 'Rank'),
                                  items: List.generate(
                                    m,
                                    (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}')),
                                  ),
                                  onChanged: open ? (v) => _setRank(poll.id, post, id, v) : null,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      ],
                    if (open)
                      FilledButton(
                        onPressed: () => _submit(poll.id),
                        style: FilledButton.styleFrom(backgroundColor: brand.primary),
                        child: const Text('Submit ranked ballot'),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
