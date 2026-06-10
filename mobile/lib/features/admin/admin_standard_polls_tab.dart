import 'package:flutter/material.dart';

import '../../core/theme/kutumbika_brand_theme.dart';
import '../../core/theme/kutumbika_colors.dart';
import '../../models/poll_models.dart';
import '../../models/session_models.dart';
import '../../services/poll_service.dart';

class AdminStandardPollsTab extends StatefulWidget {
  const AdminStandardPollsTab({super.key, required this.session});

  final SessionAdmin session;

  @override
  State<AdminStandardPollsTab> createState() => AdminStandardPollsTabState();
}

class AdminStandardPollsTabState extends State<AdminStandardPollsTab> {
  final _service = PollService();
  PollBundle? _bundle;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => _loading = true);
    final bundle = await _service.fetchStandardPolls(widget.session.societyId);
    if (mounted) {
      setState(() {
        _bundle = bundle;
        _loading = false;
      });
    }
  }

  Future<void> createPoll() async {
    final qCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final opt1 = TextEditingController();
    final opt2 = TextEditingController();
    final opt3 = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create general poll'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: qCtrl,
                decoration: const InputDecoration(labelText: 'Question *'),
              ),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              TextField(controller: opt1, decoration: const InputDecoration(labelText: 'Option 1 *')),
              TextField(controller: opt2, decoration: const InputDecoration(labelText: 'Option 2 *')),
              TextField(controller: opt3, decoration: const InputDecoration(labelText: 'Option 3 (optional)')),
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
      for (final c in [qCtrl, descCtrl, opt1, opt2, opt3]) {
        c.dispose();
      }
      return;
    }

    try {
      await _service.createStandardPoll(
        societyId: widget.session.societyId,
        adminName: widget.session.admin.name,
        question: qCtrl.text,
        description: descCtrl.text,
        optionTexts: [opt1.text, opt2.text, opt3.text],
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Poll created')));
        await load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      for (final c in [qCtrl, descCtrl, opt1, opt2, opt3]) {
        c.dispose();
      }
    }
  }

  Future<void> _closePoll(SocietyPoll poll) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close poll?'),
        content: const Text('This will stop accepting new votes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Close')),
        ],
      ),
    );
    if (ok != true) return;
    await _service.closePoll(poll.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Poll closed')));
      await load();
    }
  }

  Future<void> _showVoters(PollOption option) async {
    final votes = _bundle!.votes.where((v) => v['option_id'] == option.id).toList();
    if (votes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No votes yet')));
      return;
    }

    final profiles = await _service.fetchVoterProfiles(
      votes.map((v) => v['voter_id'] as String).whereType<String>(),
    );

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(option.optionText),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: votes.map((v) {
              final voterId = v['voter_id'] as String?;
              final prof = voterId != null ? profiles[voterId] : null;
              final flat = prof?.flatNumber ?? v['flat_number'] as String? ?? '—';
              final name = prof?.name ?? 'Voter';
              return ListTile(
                dense: true,
                title: Text(name),
                subtitle: Text('Flat $flat'),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brand = KutumbikaBrandTheme.of(context);

    if (_loading) return const Center(child: CircularProgressIndicator());

    final bundle = _bundle!;
    if (bundle.polls.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          Center(
            child: Text('No general polls', style: TextStyle(color: KutumbikaColors.textMuted)),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bundle.polls.length,
      itemBuilder: (context, index) {
        final poll = bundle.polls[index];
        final options = bundle.options.where((o) => o.pollId == poll.id).toList();
        final totalVotes = options.fold<int>(0, (s, o) => s + o.votesCount);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(poll.question, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    Chip(
                      label: Text(poll.isActive ? 'Open' : 'Closed'),
                      backgroundColor: poll.isActive ? brand.primaryLight : null,
                    ),
                  ],
                ),
                if (poll.description != null && poll.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(poll.description!, style: const TextStyle(fontSize: 12, color: KutumbikaColors.textMuted)),
                  ),
                Text('$totalVotes votes', style: const TextStyle(fontSize: 11, color: KutumbikaColors.textMuted)),
                const SizedBox(height: 10),
                ...options.map((opt) {
                  final pct = totalVotes > 0 ? (opt.votesCount / totalVotes * 100).round() : 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: InkWell(
                      onTap: () => _showVoters(opt),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: brand.primary.withValues(alpha: 0.15)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: Text(opt.optionText)),
                            Text('${opt.votesCount} · $pct%', style: TextStyle(color: brand.primary, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                if (poll.isActive) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => _closePoll(poll),
                    child: const Text('Close poll'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
