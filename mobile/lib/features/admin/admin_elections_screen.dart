import 'package:flutter/material.dart';

import '../../core/theme/kutumbika_brand_theme.dart';
import '../../core/theme/kutumbika_colors.dart';
import '../../models/session_models.dart';
import '../../services/election_service.dart';
import '../../utils/election_governance.dart';
import '../../utils/election_tally.dart';

class AdminElectionsScreen extends StatefulWidget {
  const AdminElectionsScreen({
    super.key,
    required this.session,
    this.embedded = false,
  });

  final SessionAdmin session;
  final bool embedded;

  @override
  State<AdminElectionsScreen> createState() => AdminElectionsScreenState();
}

class AdminElectionsScreenState extends State<AdminElectionsScreen> {
  final _service = ElectionService();
  ElectionBundle? _bundle;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final bundle = await _service.fetchForSociety(widget.session.societyId);
    if (mounted) {
      setState(() {
        _bundle = bundle;
        _loading = false;
      });
    }
  }

  Future<void> createElection() async {
    final qCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final seatsCtrl = TextEditingController(text: '5');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create society election'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: qCtrl,
                decoration: const InputDecoration(labelText: 'Title *'),
              ),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              TextField(
                controller: seatsCtrl,
                decoration: const InputDecoration(labelText: 'Committee seats (5–20)'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
        ],
      ),
    );

    if (ok != true || qCtrl.text.trim().isEmpty) {
      qCtrl.dispose();
      descCtrl.dispose();
      seatsCtrl.dispose();
      return;
    }

    try {
      await _service.createElection(
        societyId: widget.session.societyId,
        adminName: widget.session.admin.name,
        question: qCtrl.text,
        description: descCtrl.text,
        committeeSeats: int.tryParse(seatsCtrl.text) ?? 5,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Election created — nomination open')),
        );
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      qCtrl.dispose();
      descCtrl.dispose();
      seatsCtrl.dispose();
    }
  }

  Future<void> _startVoting(String pollId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Open voting?'),
        content: const Text('Residents can rank candidates during the scheduled window.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Open voting')),
        ],
      ),
    );
    if (ok != true) return;
    await _service.startVoting(pollId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Voting started')));
      await _load();
    }
  }

  Future<void> _closeElection(Map<String, dynamic> raw) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close & tally?'),
        content: const Text('Voting stops. Review results before publishing to committee.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Close')),
        ],
      ),
    );
    if (ok != true) return;

    final pollId = raw['id'] as String;
    final seats = (raw['election_committee_seats'] as num?)?.toInt() ?? 5;
    try {
      await _service.closeAndTally(
        pollId: pollId,
        options: _bundle!.options,
        ballots: _bundle!.ballots,
        committeeSeats: seats,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Election closed')));
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _publish(Map<String, dynamic> raw) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Publish to committee?'),
        content: const Text('Elected members appear in the residents’ Committee tab.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Publish')),
        ],
      ),
    );
    if (ok != true) return;

    final resultsRaw = raw['election_results'];
    if (resultsRaw is! Map) return;

    final r = Map<String, dynamic>.from(resultsRaw);
    ElectedWinner? parseWinner(dynamic w) {
      if (w is! Map) return null;
      final m = Map<String, dynamic>.from(w);
      return ElectedWinner(
        optionId: m['option_id'] as String,
        name: m['name'] as String,
        score: (m['score'] as num?)?.toInt() ?? 0,
      );
    }

    final committee = (r['committee'] as List?)
            ?.map((w) => parseWinner(w))
            .whereType<ElectedWinner>()
            .toList() ??
        [];

    final results = ElectionResultsPayload(
      president: parseWinner(r['president']),
      vicePresident: parseWinner(r['vice_president']),
      secretary: parseWinner(r['secretary']),
      treasurer: parseWinner(r['treasurer']),
      committee: committee,
      talliedAt: r['tallied_at'] as String? ?? '',
    );

    try {
      await _service.publishToCommittee(
        societyId: widget.session.societyId,
        pollId: raw['id'] as String,
        results: results,
        options: _bundle!.options.where((o) => o['poll_id'] == raw['id']).toList(),
        termFrom: raw['election_term_from'] as String?,
        termTo: raw['election_term_to'] as String?,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Published to committee roster')),
        );
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = KutumbikaBrandTheme.of(context);

    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            color: brand.primary,
            child: _buildList(brand),
          );

    if (widget.embedded) return body;

    return Scaffold(
      appBar: AppBar(title: const Text('Society elections')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: createElection,
        icon: const Icon(Icons.add),
        label: const Text('New election'),
      ),
      body: body,
    );
  }

  Widget _buildList(KutumbikaBrandTheme brand) {
    final bundle = _bundle!;
    if (bundle.elections.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 100),
          Center(
            child: Text('No elections yet', style: TextStyle(color: KutumbikaColors.textMuted)),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bundle.elections.length,
      itemBuilder: (context, index) {
        final poll = bundle.elections[index];
        return FutureBuilder<Map<String, dynamic>?>(
          future: _service.fetchPollRaw(poll.id),
          builder: (context, snap) {
            final raw = snap.data;
            if (raw == null) return const SizedBox.shrink();

            final phase = electionPhase(raw);
            final opts = bundle.options.where((o) => o['poll_id'] == poll.id).length;
            final votes = bundle.ballots.where((b) => b['poll_id'] == poll.id).length;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(poll.question, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(
                      phaseBadgeLabel(phase),
                      style: TextStyle(fontSize: 12, color: brand.primary, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${votingWindowLabel(raw)} · $opts candidates · $votes ballots',
                      style: const TextStyle(fontSize: 11, color: KutumbikaColors.textMuted),
                    ),
                    if (raw['election_results'] is Map) ...[
                      const SizedBox(height: 8),
                      _ResultsSummary(results: Map<String, dynamic>.from(raw['election_results'] as Map)),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (phase == ElectionPhase.nomination)
                          FilledButton(
                            onPressed: () => _startVoting(poll.id),
                            child: const Text('Start voting'),
                          ),
                        if (phase == ElectionPhase.voting)
                          FilledButton(
                            onPressed: () => _closeElection(raw),
                            child: const Text('Close & tally'),
                          ),
                        if (phase == ElectionPhase.closed && raw['election_results'] != null)
                          OutlinedButton(
                            onPressed: () => _publish(raw),
                            child: const Text('Publish to committee'),
                          ),
                      ],
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

class _ResultsSummary extends StatelessWidget {
  const _ResultsSummary({required this.results});

  final Map<String, dynamic> results;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[];
    for (final post in ['president', 'vice_president', 'secretary', 'treasurer']) {
      final w = results[post];
      if (w is Map) {
        lines.add('${postDisplay[post]}: ${w['name']}');
      }
    }
    final committee = results['committee'];
    if (committee is List && committee.isNotEmpty) {
      lines.add('Committee: ${committee.length} elected');
    }
    if (lines.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((l) => Text(l, style: const TextStyle(fontSize: 12))).toList(),
    );
  }
}
