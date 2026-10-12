import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../data/gov_backend.dart';
import '../data/poll_repository.dart';
import '../models/poll_models.dart';
import '../widgets/election_results_banner.dart';
import '../widgets/gov_widgets.dart';
import 'election_section.dart';
import 'general_polls_section.dart';

enum PollsSection { elections, polls }

/// Port of web `PollManager.tsx` — Society Elections + General Polls.
class PollsPage extends StatefulWidget {
  const PollsPage({
    super.key,
    required this.societyId,
    required this.viewer,
    this.resolveViewer,
    this.initialSection = PollsSection.elections,
    this.societyName,
  });

  final String societyId;
  final PollViewer viewer;
  final Future<PollViewer> Function()? resolveViewer;
  final PollsSection initialSection;
  final String? societyName;

  @override
  State<PollsPage> createState() => _PollsPageState();
}

class _PollsPageState extends State<PollsPage> {
  late final PollRepository _repo = PollRepository(widget.societyId);
  late PollViewer _viewer = widget.viewer;
  late PollsSection _section = widget.initialSection;
  PollsBundle _bundle = const PollsBundle();
  bool _loading = true;
  Key _bannerKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _load();
    final r = widget.resolveViewer;
    if (r != null) {
      r().then((v) {
        if (mounted) setState(() => _viewer = v);
      });
    }
  }

  Future<void> _load() async {
    try {
      final b = await _repo.loadAll();
      if (mounted) {
        setState(() {
          _bundle = b;
          _bannerKey = UniqueKey();
        });
      }
    } catch (e) {
      if (mounted) GovToast.error(context, GovBackend.errorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _tab(PollsSection s, IconData icon, String label, int count) {
    final t = context.tokens;
    final on = _section == s;
    return Expanded(
      child: Material(
        color: on ? t.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          onTap: () => setState(() => _section = s),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: on ? t.primaryForeground : t.mutedForeground),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: on ? t.primaryForeground : t.mutedForeground)),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: on ? AppTokens.tint(t.primaryForeground, 0.2) : AppTokens.tint(t.primary, 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('$count', style: TextStyle(fontSize: 10, color: on ? t.primaryForeground : t.primary)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return PageContainer(
      onRefresh: _load,
      children: [
        PageHeader(
          icon: Icons.how_to_vote_outlined,
          iconColor: t.accent,
          title: context.tr('Polls & Elections', 'मतदान व चुनाव'),
          subtitle: context.tr(
              'Two sections: Society Elections (7-member MC, one vote per member) and General Polls (single-choice questions).',
              'दो भाग: सोसायटी चुनाव (7-सदस्यीय प्रबंध समिति, प्रति सदस्य एक मत) और सामान्य मतदान (एकल-विकल्प प्रश्न)।'),
          bottomSpacing: 12,
        ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: t.muted, borderRadius: BorderRadius.circular(AppTokens.radius)),
          child: Row(
            children: [
              _tab(PollsSection.elections, Icons.account_balance_outlined, context.tr('Society Elections', 'सोसायटी चुनाव'),
                  _bundle.activeElections.length),
              const SizedBox(width: 6),
              _tab(PollsSection.polls, Icons.checklist, context.tr('General Polls', 'सामान्य मतदान'),
                  _bundle.standardPolls.where((p) => p.isActive).length),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_loading)
          const LoadingView()
        else if (_section == PollsSection.elections) ...[
          if (!_viewer.isResident) ElectionResultsBanner(key: _bannerKey, societyId: widget.societyId),
          ElectionSection(repo: _repo, viewer: _viewer, bundle: _bundle, onReload: _load, societyName: widget.societyName),
        ] else
          GeneralPollsSection(
            repo: _repo,
            viewer: _viewer,
            bundle: _bundle,
            onReload: _load,
            onGoToElections: () => setState(() => _section = PollsSection.elections),
          ),
      ],
    );
  }
}
