import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../data/gov_backend.dart';
import '../data/poll_repository.dart';
import '../logic/text_compare.dart';
import '../models/poll_models.dart';
import '../widgets/gov_widgets.dart';
import '../widgets/poll_documents_panel.dart';

/// "General Polls" section of web `PollManager.tsx`.
class GeneralPollsSection extends StatefulWidget {
  const GeneralPollsSection({
    super.key,
    required this.repo,
    required this.viewer,
    required this.bundle,
    required this.onReload,
    required this.onGoToElections,
  });

  final PollRepository repo;
  final PollViewer viewer;
  final PollsBundle bundle;
  final Future<void> Function() onReload;
  final VoidCallback onGoToElections;

  @override
  State<GeneralPollsSection> createState() => _GeneralPollsSectionState();
}

class _GeneralPollsSectionState extends State<GeneralPollsSection> {
  bool _showForm = false;
  final _question = TextEditingController();
  final _description = TextEditingController();
  final List<TextEditingController> _options = [TextEditingController(), TextEditingController()];
  bool _creating = false;
  final Set<String> _voting = {};

  bool get _isResident => widget.viewer.isResident;

  @override
  void dispose() {
    _question.dispose();
    _description.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _create() async {
    final opts = _options.map((c) => c.text).toList();
    if (_question.text.isEmpty || opts.where((o) => o.trim().isNotEmpty).length < 2) return;
    setState(() => _creating = true);
    try {
      await widget.repo.createStandardPoll(
        question: _question.text,
        description: _description.text,
        options: opts,
        adminName: widget.viewer.adminName,
      );
      if (!mounted) return;
      _question.clear();
      _description.clear();
      setState(() {
        for (final c in _options.skip(2)) {
          c.dispose();
        }
        _options.removeRange(2, _options.length);
        for (final c in _options) {
          c.clear();
        }
        _showForm = false;
      });
      GovToast.ok(context, context.tr('Poll created', 'मतदान बनाया गया'));
      await widget.onReload();
    } catch (e) {
      if (mounted) GovToast.error(context, GovBackend.errorText(e));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _vote(PollRow poll, PollOptionRow opt) async {
    final v = widget.viewer;
    if (widget.bundle.votes.any((x) => x.pollId == poll.id && x.voterId == v.voterId)) {
      GovToast.error(context, context.tr('Already voted', 'पहले ही मत दे चुके हैं'));
      return;
    }
    setState(() => _voting.add(poll.id));
    try {
      await widget.repo.castVote(
        pollId: poll.id,
        optionId: opt.id,
        voterId: v.voterId,
        flatNumber: v.flatNumber,
        currentCount: opt.votesCount,
      );
      if (!mounted) return;
      GovToast.ok(context, context.tr('Vote cast!', 'मत दिया गया!'));
      await widget.onReload();
    } catch (e) {
      if (mounted) GovToast.error(context, GovBackend.errorText(e));
    } finally {
      if (mounted) setState(() => _voting.remove(poll.id));
    }
  }

  Future<void> _close(PollRow poll) async {
    final ok = await govConfirm(
      context,
      title: context.tr('Close Poll?', 'मतदान बंद करें?'),
      message: context.tr('This will stop accepting new votes.', 'इसके बाद नए मत स्वीकार नहीं होंगे।'),
      confirmLabel: context.tr('Yes, Close', 'हाँ, बंद करें'),
    );
    if (!ok) return;
    try {
      await widget.repo.closePoll(poll.id);
      if (!mounted) return;
      await AppFeedback.success(context, title: context.tr('Closed!', 'बंद!'), message: context.tr('Poll has been closed', 'मतदान बंद कर दिया गया'));
      await widget.onReload();
    } catch (e) {
      if (mounted) GovToast.error(context, GovBackend.errorText(e));
    }
  }

  void _voteDetail(PollOptionRow opt) {
    final votes = widget.bundle.votes.where((v) => v.optionId == opt.id).toList();
    if (opt.votesCount == 0 && votes.isEmpty) {
      GovToast.info(context, context.tr('No votes for this option yet', 'इस विकल्प पर अभी कोई मत नहीं'));
      return;
    }
    final profiles = widget.bundle.voterProfiles;
    votes.sort((a, b) => localeCompare(profiles[a.voterId]?.name ?? '', profiles[b.voterId]?.name ?? ''));
    showGovSheet<void>(
      context,
      title: '${context.tr('Votes', 'मत')}: ${opt.optionText}',
      description: votes.isNotEmpty
          ? context.tr('${votes.length} ${votes.length == 1 ? 'person' : 'people'} chose this option.', '${votes.length} लोगों ने यह विकल्प चुना।')
          : context.tr('Individual votes are loaded from the database.', 'व्यक्तिगत मत डेटाबेस से लोड होते हैं।'),
      builder: (ctx, _) {
        if (votes.isEmpty) {
          return Text(
            ctx.tr('No vote rows in the database for this option. Try refreshing; option totals may need to be reconciled.',
                'इस विकल्प हेतु डेटाबेस में कोई मत पंक्ति नहीं। रीफ़्रेश करें; विकल्प योग का मिलान आवश्यक हो सकता है।'),
            style: AppText.caption(ctx),
          );
        }
        return Column(
          children: [
            for (final v in votes)
              Builder(builder: (_) {
                final prof = profiles[v.voterId];
                final flat = (prof?.flatNumber ?? '').isNotEmpty ? prof!.flatNumber : (v.flatNumber ?? '—');
                final label = prof?.name ??
                    (v.voterType.toLowerCase() == 'resident' ? ctx.tr('Resident', 'निवासी') : (v.voterType.isEmpty ? ctx.tr('Voter', 'मतदाता') : v.voterType));
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(border: Border.all(color: ctx.tokens.border), borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
                  child: Row(
                    children: [
                      Expanded(child: Text(label, style: AppText.bodyMedium(ctx))),
                      Text('${ctx.tr('Flat', 'फ्लैट')} $flat', style: AppText.caption(ctx)),
                    ],
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  Widget _pollCard(PollRow poll) {
    final t = context.tokens;
    final opts = widget.bundle.optionsFor(poll.id);
    final total = opts.fold<int>(0, (s, o) => s + o.votesCount);
    final hasVoted = widget.bundle.votes.any((v) => v.pollId == poll.id && v.voterId == widget.viewer.voterId);
    final canVote = _isResident && poll.isActive && !hasVoted;
    return CardSection(
      margin: const EdgeInsets.only(bottom: 12),
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
                    Text(context.tr('GENERAL POLL', 'सामान्य मतदान'), style: AppText.tiny(context).copyWith(fontWeight: FontWeight.w500)),
                    Text(poll.question, style: AppText.sectionTitle(context)),
                    if ((poll.description ?? '').isNotEmpty) Text(poll.description!, style: AppText.caption(context)),
                  ],
                ),
              ),
              StatusBadge(
                poll.isActive ? context.tr('Active', 'सक्रिय') : context.tr('Closed', 'बंद'),
                tone: poll.isActive ? BadgeTone.success : BadgeTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(context.tr('$total votes', '$total मत'), style: AppText.caption(context)),
          const SizedBox(height: 10),
          for (final o in opts)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: canVote
                  ? Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                        onTap: _voting.contains(poll.id) ? null : () => _vote(poll, o),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(border: Border.all(color: t.border), borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
                          child: Text(o.optionText, style: AppText.body(context)),
                        ),
                      ),
                    )
                  : Builder(builder: (_) {
                      final pct = total > 0 ? o.votesCount / total : 0.0;
                      final tappable = o.votesCount > 0 || widget.bundle.votes.any((v) => v.optionId == o.id);
                      return InkWell(
                        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                        onTap: () => _voteDetail(o),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                          child: Opacity(
                            opacity: tappable ? 1 : 0.9,
                            child: Stack(
                              children: [
                                Positioned.fill(child: ColoredBox(color: AppTokens.tint(t.muted, 0.5))),
                                Positioned.fill(
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: pct.clamp(0, 1).toDouble(),
                                    child: ColoredBox(color: AppTokens.tint(t.primary, 0.1)),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Row(
                                    children: [
                                      Expanded(child: Text(o.optionText, style: AppText.body(context))),
                                      Text('${o.votesCount} (${(pct * 100).toStringAsFixed(0)}%)', style: AppText.mono(context, size: 12)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
            ),
          PollDocumentsPanel(
            pollId: poll.id,
            repo: widget.repo,
            isAdmin: !_isResident,
            documents: widget.bundle.documents,
            createdBy: widget.viewer.adminName,
            onChanged: widget.onReload,
          ),
          if (!_isResident && poll.isActive)
            Align(alignment: Alignment.centerLeft, child: LinkText(context.tr('Close poll', 'मतदान बंद करें'), color: t.destructive, onTap: () => _close(poll))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final polls = widget.bundle.standardPolls;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTokens.tint(t.card, 0.4),
            border: Border.all(color: AppTokens.tint(t.border, 0.8)),
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          ),
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: context.tr('General polls are for society questions and feedback — one option per member. For managing-committee posts use ',
                  'सामान्य मतदान सोसायटी प्रश्नों व प्रतिक्रिया हेतु हैं — प्रति सदस्य एक विकल्प। प्रबंध समिति पदों हेतु ')),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: GestureDetector(
                  onTap: widget.onGoToElections,
                  child: Text(context.tr('Society Elections', 'सोसायटी चुनाव'),
                      style: TextStyle(fontSize: 12, color: t.primary, fontWeight: FontWeight.w500, decoration: TextDecoration.underline, decorationColor: t.primary)),
                ),
              ),
              TextSpan(text: context.tr('.', ' का उपयोग करें।')),
            ]),
            style: AppText.caption(context),
          ),
        ),
        const SizedBox(height: 12),
        if (!_isResident) ...[
          AppButton(label: context.tr('New general poll', 'नया सामान्य मतदान'), icon: Icons.add, onPressed: () => setState(() => _showForm = !_showForm)),
          const SizedBox(height: 12),
          if (_showForm)
            CardSection(
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(context.tr('NEW GENERAL POLL', 'नया सामान्य मतदान'), style: AppText.fieldLabel(context)),
                  const SizedBox(height: 10),
                  AppTextField(controller: _question, hint: context.tr('Question', 'प्रश्न'), caps: false),
                  const SizedBox(height: 10),
                  AppTextField(controller: _description, hint: context.tr('Description (optional)', 'विवरण (वैकल्पिक)'), maxLines: 3, minLines: 2, caps: false),
                  const SizedBox(height: 10),
                  for (final (i, c) in _options.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(child: AppTextField(controller: c, hint: '${context.tr('Option', 'विकल्प')} ${i + 1}', caps: false)),
                          if (i > 1)
                            IconButton(
                              onPressed: () => setState(() => _options.removeAt(i).dispose()),
                              icon: Icon(Icons.delete_outline, size: 18, color: t.destructive),
                            ),
                        ],
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: LinkText('+ ${context.tr('Add option', 'विकल्प जोड़ें')}', onTap: () => setState(() => _options.add(TextEditingController()))),
                  ),
                  const SizedBox(height: 8),
                  AppButton(label: context.tr('Create poll', 'मतदान बनाएँ'), loading: _creating, onPressed: _create),
                ],
              ),
            ),
        ],
        if (polls.isEmpty)
          CardSection(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(Icons.checklist, size: 32, color: AppTokens.tint(t.mutedForeground, 0.5)),
                const SizedBox(height: 8),
                Text(context.tr('No general polls yet.', 'अभी कोई सामान्य मतदान नहीं।'), style: AppText.body(context).copyWith(color: t.mutedForeground)),
                if (_isResident)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(context.tr('The admin will create polls for society questions here.', 'प्रशासक यहाँ सोसायटी प्रश्नों हेतु मतदान बनाएँगे।'),
                        textAlign: TextAlign.center, style: AppText.caption(context)),
                  ),
              ],
            ),
          )
        else
          for (final p in polls) _pollCard(p),
      ],
    );
  }
}
