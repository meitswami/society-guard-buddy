import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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

    final statementCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Nominate for ${postDisplay[post] ?? post}'),
        content: TextField(
          controller: statementCtrl,
          maxLines: 5,
          maxLength: 2000,
          decoration: const InputDecoration(
            labelText: 'Why should members prefer you?',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
        ],
      ),
    );

    if (ok != true) {
      statementCtrl.dispose();
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
        nominationStatement: statementCtrl.text,
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
    } finally {
      statementCtrl.dispose();
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

  Future<void> _openDoc(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
            final nomOpen = raw != null && isNominationWindowOpen(raw);
            final phase = raw != null ? electionPhase(raw) : ElectionPhase.closed;
            final opts = bundle.options.where((o) => o['poll_id'] == poll.id).toList();
            final docs = bundle.documents.where((d) => d['poll_id'] == poll.id).toList();
            final postsFromOpts = opts.map((o) => o['election_post'] as String?).whereType<String>().toSet();
            final posts = phase == ElectionPhase.nomination
                ? threeExecutivePosts.where((p) => raw != null && isPostOpenForNomination(raw, p)).toList()
                : [
                    ...threeExecutivePosts.where(postsFromOpts.contains),
                    ...postsFromOpts.where((p) => !threeExecutivePosts.contains(p)),
                  ];

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(poll.question, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    Text(
                      '${phaseBadgeLabel(phase)}${open ? ' · vote now' : ''}${nomOpen ? ' · nominate now' : ''}',
                      style: const TextStyle(fontSize: 12, color: KutumbikaColors.textMuted),
                    ),
                    if (raw != null) ...[
                      Text(
                        'Nomination: ${nominationWindowLabel(raw)}',
                        style: const TextStyle(fontSize: 11, color: KutumbikaColors.textMuted),
                      ),
                      Text(
                        'Voting: ${votingWindowLabel(raw)}',
                        style: const TextStyle(fontSize: 11, color: KutumbikaColors.textMuted),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (docs.isNotEmpty) ...[
                      const Text('Documents', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      ...docs.map((d) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.attach_file, size: 18),
                            title: Text(d['title'] as String? ?? 'Document', style: const TextStyle(fontSize: 13)),
                            subtitle: Text(d['doc_kind'] as String? ?? '', style: const TextStyle(fontSize: 11)),
                            onTap: () => _openDoc(d['file_url'] as String? ?? ''),
                          )),
                      const SizedBox(height: 8),
                    ],
                    if (phase == ElectionPhase.nomination) ...[
                      if (!nomOpen)
                        Text(
                          'Nomination opens in the scheduled window',
                          style: TextStyle(fontSize: 12, color: Colors.amber.shade800),
                        ),
                      if (nomOpen)
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
                    ],
                    if (opts.isNotEmpty) ...[
                      const Divider(),
                      const Text('Nominees', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      ...opts.map((o) {
                        final statement = o['nomination_statement'] as String?;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '· ${o['option_text']} (${postDisplay[o['election_post']] ?? o['election_post']})',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              if (statement != null && statement.isNotEmpty)
                                Text(statement, style: const TextStyle(fontSize: 11, color: KutumbikaColors.textMuted)),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                    ],
                    if (phase == ElectionPhase.voting)
                      for (final post in posts) ...[
                        Text(postDisplay[post] ?? post, style: TextStyle(fontWeight: FontWeight.w600, color: brand.primary)),
                        const SizedBox(height: 6),
                        ...opts.where((o) => o['election_post'] == post).map((o) {
                          final id = o['id'] as String;
                          final m = opts.where((x) => x['election_post'] == post).length;
                          final current = _rankings[poll.id]?[post]?[id];
                          final statement = o['nomination_statement'] as String?;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
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
                                if (statement != null && statement.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(statement,
                                        style: const TextStyle(fontSize: 11, color: KutumbikaColors.textMuted)),
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
