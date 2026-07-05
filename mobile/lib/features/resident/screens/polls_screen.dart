import 'package:flutter/material.dart';

import '../../../core/theme/kutumbika_brand_theme.dart';
import '../../../core/theme/kutumbika_colors.dart';
import '../../../models/poll_models.dart';
import '../../../models/session_models.dart';
import '../../../services/member_service.dart';
import '../../../services/poll_service.dart';
import 'elections_screen.dart';

class PollsScreen extends StatefulWidget {
  const PollsScreen({super.key, required this.session});

  final SessionResident session;

  @override
  State<PollsScreen> createState() => _PollsScreenState();
}

class _PollsScreenState extends State<PollsScreen> {
  final _pollService = PollService();
  final _memberService = MemberService();
  PollBundle? _bundle;
  String? _voterMemberId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final member = await _memberService.findByPhone(
        widget.session.resident.flatId,
        widget.session.resident.phone,
      );
      final bundle = await _pollService.fetchForSociety(widget.session.societyId);
      if (!mounted) return;
      setState(() {
        _voterMemberId = member?.id;
        _bundle = bundle;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  bool _hasVoted(String pollId) {
    final voterId = _voterMemberId;
    if (voterId == null) return false;
    return _bundle!.votes.any((v) => v['poll_id'] == pollId && v['voter_id'] == voterId);
  }

  Future<void> _vote(SocietyPoll poll, PollOption option) async {
    final voterId = _voterMemberId;
    if (voterId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link your phone to a household member to vote')),
      );
      return;
    }
    if (_hasVoted(poll.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You already voted on this poll')),
      );
      return;
    }

    try {
      await _pollService.castVote(
        pollId: poll.id,
        optionId: option.id,
        voterId: voterId,
        flatNumber: widget.session.resident.flatNumber,
        currentVotesCount: option.votesCount,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vote recorded')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not vote: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = KutumbikaBrandTheme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Polls'),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ElectionsScreen(session: widget.session)),
              );
            },
            icon: const Icon(Icons.how_to_vote),
            label: const Text('Elections'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _buildList(brand),
                ),
    );
  }

  Widget _buildList(KutumbikaBrandTheme brand) {
    final bundle = _bundle!;
    final standardPolls = bundle.polls.where((p) => !p.isElection).toList();

    if (standardPolls.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(child: Text('No active polls', style: TextStyle(color: KutumbikaColors.textMuted))),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: standardPolls.length,
      itemBuilder: (context, index) {
        final poll = standardPolls[index];
        final options = bundle.options.where((o) => o.pollId == poll.id).toList();
        final voted = _hasVoted(poll.id);

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
                      child: Text(
                        poll.question,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                    ),
                    if (!poll.isActive)
                      const Chip(label: Text('Closed'), padding: EdgeInsets.zero),
                  ],
                ),
                if (poll.description != null && poll.description!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(poll.description!, style: const TextStyle(color: KutumbikaColors.textMuted)),
                ],
                const SizedBox(height: 12),
                ...options.map((opt) {
                  final total = options.fold<int>(0, (s, o) => s + o.votesCount);
                  final pct = total > 0 ? (opt.votesCount / total * 100).round() : 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: poll.isActive && !voted ? () => _vote(poll, opt) : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: brand.primary.withValues(alpha: 0.2)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: Text(opt.optionText)),
                            Text(
                              '$pct%',
                              style: TextStyle(color: brand.primary, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                if (voted)
                  Text('You voted', style: TextStyle(fontSize: 12, color: brand.primary)),
              ],
            ),
          ),
        );
      },
    );
  }
}
